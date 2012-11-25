---
title: Qt and Websockets
kind: article
created_at: 2012-08-19 12:00:00 -4000
---
# <%=h @item[:title] %>

As most people are aware, HTML5 is the latest revision of the HTML standard that's all the rage nowadays. HTML5 comes with a lot of cool new features, but one new protocol that has been developed to ease bi-directional communication between a webpage and a server is called [WebSockets](https://en.wikipedia.org/wiki/WebSockets). WebSockets allow a client (webpage, or other) to open a TCP connection with a server and provides a low-level framing protocol to allow messages to be sent each way.


Normally, the websocket client is some JavaScript in a browser, and the server is on some remote machine. However, sometimes you might need to connect to an existing webserver with a non-JS client. Say, if you want to support web and native clients, and not have to manage two different communication stacks on the backend. I needed to be able to communicate with a WebSocket server from [Tomahawk](http://www.tomahawk-player.org/ "Tomahawk Player"), so I set about looking to see if someone had already written an easy-to-use client library for us C++/Qt developers. 

Turns out there's not much out there in C++/Qt, with three notable exceptions:

* The WebSocket support provided as a part of QtWebKit
* [QtWebSocket](https://gitorious.org/qtwebsocket) provides a pure-Qt implementation of a WebSocket server, but no client.
* [websocket++](https://github.com/zaphoyd/websocketpp), a c++/boost::asio implementation of both a client and a server.


As QtWebKit supports many of the new HTML5 features, it also contains an implementation of a WebSocket client. It's as easy as doing the following:


    var socket = new WebSocket("ws://echo.websocket.org");
    socket.onmessage = function(msg) { console.log("Message: " + msg.data); };
    socket.send("Hi!")

However, it turns out the protocol version of WebSockets that QtWebkit implements is the so-called Hixie76 version, which is from May 2010. The RFC version ([RFC 6455](https://tools.ietf.org/html/rfc6455)) is not compatible with the older Hixie76 and Hybi-* protocols, so if the server you need to connect to only supports the RFC, QtWebKit is not an option. That leaves you with websocket++.

However, websocket++ is built via handwritten Makefiles, and the boost::asio code is very far from what Qt-loving developers are accustomed to. So I did my bit and tried to make it easier: by [porting it to cmake](https://github.com/lfranchi/websocketpp/commit/1a797f7de5a536d9741726a139ff9dbf7f96d1df "CMake Port") and [adding a Qt wrapper](https://github.com/lfranchi/websocketpp/commit/bc6d0fe96610ff7d6bd619a82f793b191c1a9405 "Qt Wrapper"). Now communicating to a RFC ws:// or wss:// endpoint is this easy:

    WebSocketWrapper ws("ws://echo.websocket.org");
    connect(&amp;ws, SIGNAL(message(QString)), this, SLOT(onMessage(QString)));
    ws.start();
    ws.send("Hello Websocket!")</pre>;


You can find my fork of websocket++ here:

[https://github.com/lfranchi/websocketpp](https://github.com/lfranchi/websocketpp "Websocket++ fork")

It will automatically handshake with both plain-text servers and wss:// urls over TLS. It's not finished---particularly, self signed certs are not being accepted yet, and it hasn't been comprehensively tested yet. But as I use it in the upcoming months the warts will be ironed out, and I hope it's useful for other Qt developers who need an easy and robust way to talk to a WebSocket server.