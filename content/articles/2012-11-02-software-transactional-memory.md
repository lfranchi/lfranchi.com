---
title: Software Transactional Memory
kind: article
created_at: 2012-11-02 06:33:00 -4000
---
# <%=h @item[:title] %>

Following on from my last post, here's my first report about the topics i've been working on and learning about here at Hacker School. My major project of the last two weeks has been twofold: learning more about Software Transactional Memory (STM) as a technique for writing safe performant concurrent code, and getting more familiar with writing real-world Python code.

In order to learn more about STM i've been porting Clojure's STM system to clojure-py, and it's been a good way to force myself to fully understand how the STM system works---there's nothing like having to debug code to force to you understand it :) This blog post is meant to serve a guide for myself and others to STMs in general and clojure's STM in particular.

Essentially this will be a condensed and less useful version of this quite amazing article by R. Mark Vollkmann, [Software Transactional Memory](http://java.ociweb.com/mark/stm/article.html), where he goes through both the idea behind STM systems and then does a deep dive into the clojure STM itself. So while this blog post will pale in comparison to that STM bible, I hope it'll provide an overview and guide that can lay the foundation for deeper exploration.

Why STM?
========

Writing concurrent code is more and more common, and the main tools I was familiar with before learning Clojure were your average low-level locking constructs: mutexes, semaphores, condition variables, etc. They all rely on explicit locking---the programmer needs to be aware of and properly manage concurrent access to shared state, carefully locking the most granular bits of state while at the same time avoiding deadlocks or livelocks between threads. 

Writing safe multithreaded code is hard, not in small part due to the fact that reasoning about concurrent access is really tough---imagining possible pitfalls, writing the proper locks around your code, and then testing it are all challenging to do correctly.

On top of the difficulty of writing safe multithreaded code, a fundamental feature of lock-based code is that it is pessimistic. Locks assume that access to shared state needs to be exclusively accessed, and no other threads can access the same code at the same time (yes, there are read-write-locks, lock-free data structures, etc. With enough pain, anything is possible). STM systems operate on the opposite assumption: they are optimistic in nature. That is, they allow concurrent reads and writes to any variables with no user-space locking, and transactions will automatically be retried if there is a disagreement (or conflict) about the state or value of a variable. If it turns out, at runtime, that there isn't any conflict, there's no retiring that needs to happen

STM Overview
===========

So what is Software Transactional Memory anyway? STM is a way of writing concurrent code that accesses shared memory without having to worry about individual synchronization/serialization of the shared memory accesses. A transaction in clojure looks a bit like this:

    ; Setup
    (def r (ref 1))
    (defn divide-by-two [x] (/ x 2))

    ; Transaction
    (dosync
        (alter r inc)
        (alter r divide-by-two))
    
    (println @r) ; prints out "1" ((1 + 1) / 2)

The important part is that a transaction is enclosed in a block: (dosync ...body...) and all operations in the body are run in this one transaction. The body modifies global state---r in this example---without worrying about locking or who else might be trying to twiddle with r at the same time. 

The underlying semantics are quite simple:

1. Transactions are atomic. This means that, to a third party observer, all changes to shared state in a transaction either happen at the same time, or do not happen at all. There is no in-between inconsistent state that is ever exposed---this allows you to synchronize changes to multiple variables in one atomic step.
2. Transactions operate on a snapshot of the world. Any reads to shared state in a transaction gets that piece of state as it was when the transaction was started. That means any writes that happen to shared state *after* a transaction has begun are not seen in the transaction. A transaction gets a picture of the world at the time that the transaction started, and since all transactions are atomic, that picture is guaranteed to be a consistent snapshot of the world.
3. Transactions will be retried in case of a conflict. This means that if a transaction tries to edit shared state that has been since changed by another transaction, or if it tries to edit state that is also being edited by another concurrent transaction, it might be automatically re-tried until it is able to successfully run without conflicts. Since the body of transactions can be re-run multiple (in some case many) times, transactions must not have any side effects. Any side effects might be fired multiple times, resulting in very unexpected behavior.

The result of the above 3 guarantees mean that it is exceedingly easy to write threaded or asynchronous code that operates on shared state. To take a concrete example, Rich Hickey (the author of Clojure) wrote a now-famous demo that is a [small ant simulator](http://blip.tv/clojure/clojure-concurrency-819147). The simulator keeps track of a 80x80 world, where each cell might have an ant, food, and/or pheromones in it. The UI needs to refresh every so often and draw the current state of the world, while at the same time any number of independent, asynchronous, ants need to manipulate the world (by either moving around, eating food, or leaving pheromones).

The simulation then has many many threads that are all accessing, modifying, and reading the state of the world at the same time. The painting thread needs a consistent view of the world (so ants can't be in two places at once). By doing all of the drawing at once in a transaction, the STM ensures that every other change to the world has completed, and that if there are any changes that happen during the painting, they are not visible to the painter thread. Likewise, each ant is run asynchronously (as a thread in a thread pool). Since each ant continuously edits the world, the fact that each ant can just make the changes that it wants to do, without having to worry about overwriting or conflicting with other threads. The STM ensures that each ant's operations are properly serialized and that ants never find themselves in-between spaces. 

Simulation code: [https://gist.github.com/1494094](https://gist.github.com/1494094)

STM Internals
==========

This blog post is already too verbosely long, so an in-depth overview of how the STM is implemented will have to wait for a future post. However, here's a short overview of the different pieces that work together to  run the STM. This assumes a basic knowledge of clojure---refs and operations on refs such as commute, alter, ref-set, etc.

Ref
=====

A ref is a variable with the concept of time. Since data is immutable in Clojure, whenever you dereference a ref, you get a piece of data that is guaranteed never to change. If a transaction modifies the ref in the future, you're still holding on to a 100% valid piece of data. Refs keep track of a value history---a linked list that contains the value of the ref at a particular point in time. 

When a transaction reads a reference, it looks for a value that was written *before* the start of the transaction, and that is how all reads in a transaction see a snapshot of the world. All writes to a ref, conversely, set the value in the history chain and give it a timestamp---the point that the value was committed. 

Any alter/commute/ref-set operations on a transaction simply call the associated method in LockingTransaction: doCommute, doSet. 

LockingTransaction
=================

LockingTransaction is the main STM handling class. It's a thread-local object, so every running thread runs a separate transaction, and multiple transactions may be running at once. When the user runs a transaction with (dosync... ), a transaction object is created and it is given the body of the transaction to run. All operations on refs that occur during a transaction are logged---the newly changed values are temporarily stored by the transaction. When the body is completed, the transaction attempts to commit---that is, it attempts to get exclusive write access to the changed refs, and to change their values all at once. If there's a conflict during the run or commit process, the transaction is automatically re-tried, values are re-logged, and committing happens again. 

STM Overhead
===========

One of the main criticisms of STM is that it adds overhead. I don't have any hard numbers, but according to [this wikipedia article](https://en.wikipedia.org/wiki/Software_transactional_memory), the performance hit due to having to keep track of extra values (as each ref has a history chain of previous values) is usually not worse than two times as bad as fine-grained locking. The performance is worse the smaller number of processors/cores that are available, of course---and the more true concurrency that there is to exploit, the more the benefits of not having to worry about individual locking show through.



The more I work with STM systems the less I want to go back to writing tedious and error-prone locked code :) 