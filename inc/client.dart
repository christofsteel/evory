library chat;

import 'dart:html';
import 'dart:json';
part 'config.dart';

ChatConnection  chatConnection;
MessageInput    messageInput;
UsernameInput   usernameInput;
ChatWindow      chatWindow;

class ChatConnection {
  WebSocket webSocket;
  String url;

  ChatConnection(this.url) {
    _init();
  }

  send(String from, String message) {
    var encoded = JSON.stringify({'F': from, 'M': message});
    _sendEncodedMessage(encoded);
  }

  _receivedEncodedMessage(String encodedMessage) {
    Map message = JSON.parse(encodedMessage);
    if (message['F'] != null) {
      chatWindow.displayMessage(message['M'], message['F']);
    }
  }

  _sendEncodedMessage(String encodedMessage) {
    if (webSocket != null && webSocket.readyState == WebSocket.OPEN) {
      webSocket.send(encodedMessage);
    } else {
      print('WebSocket not connected, message $encodedMessage not sent');
    }
  }

  _init([int retrySeconds = 2]) {
    bool encounteredError = false;
    chatWindow.displayNotice("Connecting to Web socket");
    webSocket = new WebSocket(url);

    scheduleReconnect() {
      chatWindow.displayNotice('web socket closed, retrying in $retrySeconds seconds');
      if (!encounteredError) {
        window.setTimeout(() => _init(retrySeconds*2), 1000*retrySeconds);
      }
      encounteredError = true;
    }

    webSocket.on.open.add((e) {
      chatWindow.displayNotice('Connected');
    });

    webSocket.on.close.add((e) => scheduleReconnect());
    webSocket.on.error.add((e) => scheduleReconnect());

    webSocket.on.message.add((MessageEvent e) {
      print('received message ${e.data}');
      _receivedEncodedMessage(e.data);
    });
  }
}

abstract class View<T> {
  final T elem;

  View(this.elem) {
    bind();
  }

  // bind to event listeners
  void bind() { }
}

class MessageInput extends View<InputElement> {
  MessageInput(InputElement elem) : super(elem);

  bind() {
    elem.on.change.add((e) {
      chatConnection.send(usernameInput.username, message);
      chatWindow.displayMessage(message, usernameInput.username);
      elem.value = '';
    });
  }

  disable() {
    elem.disabled = true;
    elem.value = 'Enter username';
  }

  enable() {
    elem.disabled = false;
    elem.value = '';
  }

  String get message => elem.value;

}

class UsernameInput extends View<InputElement> {
  UsernameInput(InputElement elem) : super(elem);

  bind() {
    elem.on.change.add((e) => _onUsernameChange());
  }

  _onUsernameChange() {
    if (!elem.value.isEmpty()) {
      messageInput.enable();
    } else {
      messageInput.disable();
    }
  }

  String get username => elem.value;
}

class ChatWindow extends View<Element> {
  ChatWindow(Element elem) : super(elem);

  displayMessage(String msg, String from) {
    _display("$from: $msg");
  }

  displayNotice(String notice) {
    _display("[system]: $notice");
  }

  _display(String str) {
    elem.addHTML("<span>${str}</span><br/>");
//    elem.text = "${elem.text}$str";
    //scroll down
    //does not work in firefox -.-
    //count lines
//    int lines = elem.text.split("\n").length;
//    elem.scrollByLines(lines);
  }
}

main() {
  Element chatElem = query('#chat-display');
  InputElement usernameElem = query('#chat-username');
  InputElement messageElem = query('#chat-message');
  chatWindow = new ChatWindow(chatElem);
  usernameInput = new UsernameInput(usernameElem);
  messageInput = new MessageInput(messageElem);
  chatConnection = new ChatConnection(websocketuri);
}
