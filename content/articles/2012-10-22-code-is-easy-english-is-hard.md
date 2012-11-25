---
title: Writing code is easy, writing English is hard
kind: article
created_at: 2012-10-22 12:00:00 -4000
---
# <%=h @item[:title] %>


Here I am at the beginning of week 4 of Hacker School, and I've still not spent the time to sit down and reflect on what my goals are---what am I here to learn, what scares me as a programmer, and what do I want to get out of these three months? 

Fellow Hacker School-er Oskar [wrote a great blog post](http://oskarth.com/spendtime.html) about the things he wants to learn. This is my attempt to focus a bit on articulating my goals and ways to get there.

Overall goals
-------------

1. New programming languages/paradigms
2. Multi-threading, concurrency, distributed processing
3. The web stack


New programming languages/paradigms
===================================

As i've spent the better part of the last 6 or so years learning and refining my C++/Qt knowledge, it was high time I broke out of my bubble and learned something new. I decided to dive into Clojure, an opinionated purely functional language that's executed on top of the JVM.

I needed some concrete project to cut my teeth on, though, so after a tour of the syntax I started working on Ono [http://github.com/lfranchi/ono]. Ono is a headless tomahawk daemon---it will scan your music and then sit there, happily streaming it out to your other Tomahawk clients wherever they happen to be. It's not done yet, but already in just a few hundred lines of code it is able to scan some files, handle DB operations, listen for UDP broadcasts, and communicate over Tomahawk's custom TCP network protocol. 

Ono gave me a taste of real-life Clojure code, but I was looking for a more substantial project that would require me to dig deeper into Clojure, either by working on a more abstract project like a Domain Specific Language (ala [structjure](https://github.com/jamii/strucjure)) or by digging in to some internals. Thanks to Zach's suggestion I found the [clojure-py](http://gitub.com/halgary/clogure-py) project that aims to implement Clojure in pure python. As it is still only a partial port, there is still a lot of interesting work to be done at the intersection of Clojure, Python, and Java. So my next project is to port Clojure's Software Transactional Memory (STM) and refs to clojure-py. It should be meaty enough to occupy a couple of weeks and I'm interested to see how the transactional internals of Clojure's refs work.

Concrete projects
-----------------
* Ono - handy console app written in Clojure
* Clojure-py - Port closure's java STM to Clojure-py


Multi-threading, concurrency, distributed processing
====================================================

Over the last few months while I was still full-time at KDAB [http://www.kdab.com] I had been spending my 10% education time reading this [excellent book on C++11's new multithreading support](http://www.amazon.com/C-Concurrency-Action-Practical-Multithreading/dp/1933988770?tag=duckduckgo-d-20). It was the first deep-dive into multithreading I've embarked on, and while at times it's taken me a while to grasp some of the topics covered, it a topic that I find really fascinating. 

I'm particularly interested in different approaches to concurrency/multi-threading---c++11 has low-level primitives like atomics, memory ordering semantics, and system-level threads, Clojure has the STM for refs, etc. Go has lightweight coroutines, that I've heard a bit about but never really investigated. Erlang is all about message passing, or so I hear. Python users are forced to use multiple processes as the Global Interpreter Lock makes true multithreading difficult.

An extension of this is distributed/parallel processing---breaking down large data and wiring w/ massively parallel systems. Something I'm interested in but don't even know where to start.

Concrete projects
-----------------
* Write something with high contention and concurrency in Go… project TBA
* Design/Write/implement a thread-safe lock-free data structure [heap? tree? persistent trie? stack/queue?], of some sort, in some language (preferably not c++11, maybe Go if it has memory ordering semantics? rust? otherwise c++…)
* Investigate big data handling---map/reduce ala hadoop, etc?

Web Stack
=========

I'd like to familiarize myself with the pieces of the modern web stack. While I know JS/Python/etc as languages, I've never written any DOM-manipulating client-side code, or used things like postgres/mongo/riak (as different as they may be) for handling data, or had to write a REST api in any language. So I want to play around with these technologies and build something useful for me.

Concrete projects
===============
* ?
* ?


Final thoughts
==============

These are big, hairy, ambitious goals. They're hard. If all else fails, remember:

1. [Don't Panic](https://en.wikipedia.org/wiki/The_Hitchhiker's_Guide_to_the_Galaxy)
2. Write Code