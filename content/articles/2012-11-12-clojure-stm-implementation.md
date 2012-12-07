---
title: Implementation of Clojure's STM
kind: article
created_at: 2012-11-12 16:11:00 -4000
tags:
    - hackerschool
    - clojure
---
In my last post I talked about software transactional memory (STM) in general, and briefly described how Clojure implements an STM model. Here I will attempt to exhaustively describe all the moving parts that make up Clojure's STM. This won't be a complete reference guide on a method-by-method basis as [Vollkmann's article](http://java.ociweb.com/mark/stm/article.html) is, however I will attempt to make it a bit more concise and readable without sacrificing much information. 

The goal is that after reading this article, the reader should fully understand all the moving parts of how an STM (and in specific Clojure's) is implemented, and more clearly understand the trade-offs that are at play. As briefly mentioned in my last post, there is a very real performance impact that has to be kept in mind, so knowing where and why will help the reader decide when something approximating an STM is a good choice.

While I will assume the reader has already, at the minimum, skimmed the last blog post, here is a quick overview to make sure everything is clear. We are talking about the concurrent execution of independent transactions, surrounded in clojure by (dosync) blocks. Here is an example:

<% highlight :clojure do %>
    (def a (ref 0))
(def f1 (future (dosync (alter a inc))))
(def f2 (future (dosync (alter a inc))))
@f2
<% end %>
  
Each increment of 'a' is done in a different thread, potentially conflicting and in an arbitrary order. 

In the rest of this post, a 'transaction try' is defined as one particular run of a transaction. As it may or may not be successful, a transaction try may fail and be forced to retry, creating a new transaction try for the same transaction.

### Time

All transaction threads share a thread-safe atomic counter that is incremented at the beginning of each transaction try. This is the global ordering that is used to determine which transaction "started first", or if a certain ref's value was committed before or after the beginning of a transaction. Every time a transaction try begins, the transaction increments the counter and stores the result as the "start point". Every transaction also has a "commit point" that describes the time at the start of the commit process. 

### TransactionInfo

Every running transaction has an "Info" object, a collection of fields that describe this transaction. An Info object contains:

* status: an enum describing the transaction's current status (Running, Killed, Committing, Committed)
* startPoint: When this transaction-try started.
* latch: a java CountdownLatch or python threading.Event, a way for other threads to wait for this transaction to finish
* lock: A lock to protect synchronous access to latch + status. 

## Refs

A ref is a mutable reference to a piece of immutable data. Whenever you dereference a ref, you get the current value of the reference at that point in time. In essence, a ref is a variable that has the concept of time---Rich Hickey elegantly explains his fundamental disagreement with languages that don't account for time [in this video](http://www.infoq.com/presentations/Value-Identity-State-Rich-Hickey). Refs contain a few key properties:

* A history chain. This is simply a linked-list of values that this reference has had, with associated time (transaction order counter) when the value was committed.
* A number of faults. Faults will be described later, but a fault is registered on a ref if it has no value old-enough  to be read by a transaction (but has a newer value).
* A re-entrant read-write lock. This is to protect the ref from concurrent access, and each ref has one. If a ref is being read by multiple transactions, all can acquire a read lock, but at soon as a transaction needs to commit a change to a ref, a unique write lock is required.
* A transaction info object. This describes the transaction that currently "owns" this ref, if any. Null otherwise.

Clojure also contains the function 'ensure', that takes a ref and can only be called during a transaction. Ensure will acquire a read lock for the duration of the transaction, forcing any other transactions that attempt to write to this ref to be forced to retry. Ensuring a ref allows for the developer to control in a more fine-grained fashion how the STM will behave---if the developer has some knowledge that, for example, transaction A is slow and should be allowed to finish while transaction B (that does a write to a ref that A reads) can be easily reapplied, then she can 'ensure' the ref in A to make sure that the STM retries the correct transaction B. Ensure will not affect the resulting outcome of the code. 

Refs additionally have a minimum and maximum value for the length of the history chain that they keep. Clojure provides hooks for the programmer to modify these lengths, in case the programmer has some knowledge about the way in which a ref will be exercised in the STM---if a ref is written to repeatedly as soon as it is created, and meanwhile another slow transaction is trying to read the ref, forcing the ref to maintain more history items (the default is min==0, max==10) will decrease the chance that a read fails and forces the transaction to retry.

### Reading

Reading the value of a ref in a transaction is one of the simpler operations that the STM has to deal with. If this ref has previously been assigned to (this is called giving a ref an in-transaction-value) in this same transaction, a read will simply return the latest in-transaction-value. Otherwise, it tries to look up a value from the ref's history chain. It acquires a write lock on the ref for the duration of the search, as it wants to avoid another transaction modifying the history chain during the traversal process. It simply goes back through the ref's history looking for the newest committed value that was committed *before* this transaction try started. Once found, it returns the value.

If no such value was found, the only committed values for this ref were committed after this transaction try started. This will increment the fault count on the ref and retry the current transaction. 

#### Faults

The number of faults on a ref signifies how many times this ref was read in a transaction without there being an old-enough value in the history chain. It implies that this ref is being written to read from concurrently from different threads, and that there isn't enough history to find an value to use for this transaction. When a ref is committed to that has more than 0 faults, the STM will automatically increase the history chain length (as long as it is less than the max history chain value). This makes sure that refs that are being concurrently written/read keep more history and avoid expensive transaction retries. The fault system is a self-adapting tool to try to reduce retries on contentious refs.

### Writing

Writing to a ref in a transaction involves a few more involved steps than reading. First, the transaction attempts to get a write lock on the ref. If the attempt fails, another transaction has either ensured the ref, is in the process of committing to the ref, or is in the brief read process described above. However, since the transaction will wait 0.1s to acquire the lock, if another transaction is simply reading the ref value it is likely that they will finish and unlock the lock in time for this transaction to grab it. A failure forces a retry of the current transaction.

Once the lock is acquired, the transaction checks if there is a newer-committed value to the ref since the beginning of our transaction try. If there is, this transaction retries as otherwise the newly committed value would be overwritten. 

Then the transaction looks at the ref's tinfo field to see if this ref is 'owned' already by another active transaction. A ref is owned by a transaction if there has been a write to to the ref in a transaction and the transaction has not committed yet---basically it's currently being used and "will get" a new value once the owning transaction completes. At this point there is a conflict---two running-but-not-yet-committed transactions both want to modify the same ref. Who wins?

#### Barging

The mechanism to 'break a tie' when two transactions both want to edit the same ref is called barging. Transaction A will try to barge transaction B when it attempts to write to a ref that is owned by B. If the transaction that does the barge fails, it is forced to retry. A barges B iff:

1. A is at least BARGE_WAIT_SECS (0.1s) old
2. A is older than B---that is, the start point of A is less than the start point of B
3. B is currently Running, and an atomic compare-and-swap operation from Running to Killed must be successful

Essentially, the older transaction wins. If B is barged successfully, its TransactionInfo object has had its state set to Killed. When it tries to start committing, it will notice that it has been killed by another transaction and retry itself automatically.

If A loses the barge attempt, it waits up to 0.1s for B to complete (so as to let B finish---otherwise it might re-run so fast that it hits another conflict with B all over again and repeats the cycle) before retrying.


After the potential barge attempt, the writing transaction knows it owns the ref, so it sets the ref's info object to the transaction's own info. It then saves the new value that will be saved to the ref in a temporary hash-map of {ref: value} pairs, which will be committed to the ref during the committing process.

### Commutes

The Clojure STM also supports a 'commute' operation on refs. A commute is similar to an alter in that it takes a function to apply to the ref, and saves the output of the function as the new value for the ref, however, a commute is re-applied at the *end* of a transaction regardless of what the previous value of the ref was. For example, if you have two concurrent threads that are both incrementing some shared counter, it doesn't matter which one gets there first---incrementing the count is a commutative operation and the only thing that matters is that both of the actions actually occur on the ref.

When calling commute on a ref, the transaction saves the function + args to apply during the commit process, and then goes ahead and runs the transaction to save the in-transaction-value of the ref to the newly desired one.

## Transaction Committing

After a transaction runs the user's code specified in the (dosync... ) block, the transaction attempts to commit the values that were changed. It does so in a series of steps. Before writing to any ref it makes sure to acquire a write lock for the ref---if any acquiring fails (because another transaction is committing) this transaction is forced to retry. All refs locks must be acquired in order to do the commit and atomically affect the state of the world to an external observer. This prevents an inconsistent state from ever being exposed to the outside world.

### Handling Commutes

Now that the transaction is committing, the first step is to handle any commutes that were made during the transaction. If this ref has been alter'ed or ref-set'ed in another transaction and it is still running---that is, if another transaction already owns this ref---then we have a conflict that we need to resolve. This transaction attempts to barge the other transaction, and if it succeeds continues to commit as usual. Otherwise, it will retry after waiting up to 0.1s.

Now since there are no more conflicts, the transaction re-runs the commute function with the latest value of the ref, and updates the ref's in-transaction-value with the result. 

### Handling alter and ref-set

Now that all the commutes are done, the transaction has all the values to commit to the refs that have been touched. At this point it attempts to get a write lock on all refs that it needs to change.

To actually make the new value visible to the outside world, the transaction updates the ref's history chain. It will either change the oldest history chain item, update the value and timestamp, and make it the newest one (essentially rotating the history chain by one, so the former newest value is now the 2nd-newest), or create a new history chain item and prepend it to the front of the chain. The decision depends on if the history chain is at least the "min history chain" length, or if the ref has had a fault and the chain length is less than the "max history chain" length.

Regardless, the ref will now have the newly-saved value as the head of the history chain, and that item will have the timestamp of this transaction commit.

Once all of the changed refs have had their history chains updated, the main body of the commit is done. The changes have been made visible to the outside world.

### Cleanup

To clean up, the transaction releases all the write locks that it acquired (in the reverse order that it acquired them), and it releases any 'ensures' that have been placed on any refs. It atomically changes the state of the transaction from Committing to Committed.

That's it! The 'run' method is now over, and it returns the return value of the last statement in the body that was executed. This transaction has been completed successfully.

If at any point during the running or committing process the transaction threw a TransactionRetryException, the transaction will simply throw away the in-transaction-values that it saved and rerun the whole transaction. Everything starts all over again, and a transaction will try up to 10,000 times to successfully commit. If it is not able to in that number of tries, it throws an exception that is not caught and that will bubble up to the programmer's own code.

## Conclusion

I hope in this  post to have made it clear how many pieces there are in the STM that undergirds Clojure's Ref system. There are a lot of extraneous hoops that the code jumps through that aren't required if the programmer is manually using locks to share access to state. A blocking channel system like Go has is also a vastly different approach to the same problem---communication and synchronization via message passing and pipes rather than optimistically giving all operators unfettered access to the world (and dealing with conflicts internally as they come up). It is clearly a system that optimizes for a certain set of usecases---lots of concurrent writes to the same data might cause a lot of retries, for example, and might not be anywhere near as efficient as a mutex if the programmer knows where to place it.

On the other hand, STM is designed to, in my opinion, apply to the majority of multithreaded contexts where while shared access to common state happens, it is not repeated and clashing, and the programmer overhead of synchronizing and locking all possible conflicts with the proper tools becomes prohibitive. By removing the need to reason about data races, which is a tricky and dangerous business in the best of times, a STM system frees the programmer to focus on writing the bits of code that 'actually matter'. 

As with any attempt to make a programmer's life easier, though, it comes with downsides that must be understood. Remember to profile before optimizing! Premature optimization may not be the root of all evil, but might leave you with nasty code that you won't want to touch years later.