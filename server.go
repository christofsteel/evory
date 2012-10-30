package main

import (
	"code.google.com/p/go.net/websocket"
	//	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
)

var port *int = flag.Int("p", 8080, "Port to listen.")

func main() {
	flag.Parse()
	go h.run()
	http.HandleFunc("/", mainServer)
	http.Handle("/ws", websocket.Handler(webSocketHandler))
	http.HandleFunc("/inc/", sourceHandler)
	if err := http.ListenAndServe(fmt.Sprintf(":%d", *port), nil); err != nil {
		log.Fatal("ListenAndServe:", err)
	}
}

type message struct {
	F string
	M string
}

type messageConnection struct {
	Message message
	Conn    *connection
}

type hub struct {
	//Set of Connections.
	//map is a helping type for realisation
	connections map[*connection]bool
        usernames   map[*connection]string
	register    chan *connection
	unregister  chan *connection
	recive      chan *messageConnection
}

var h = hub{
	connections: make(map[*connection]bool),
        usernames:   make(map[*connection]string),
	register:    make(chan *connection),
	unregister:  make(chan *connection),
	recive:      make(chan *messageConnection),
}

func (h *hub) run() {
	for {
		select {
		case c := <-h.register:
			h.connections[c] = true
                        h.usernames[c] = ""
		case c := <-h.unregister:
			delete(h.connections, c)
                        delete(h.usernames, c)
			close(c.send)
		case mc := <-h.recive:
                        h.usernames[mc.Conn] = mc.Message.F //sets the senders transmitted username as current username
                        // if the message was '/who', then the sender gets a list of currently online usernames
                        if mc.Message.M == "/who" {
                           usernames := ""
                           for _,username := range h.usernames {
                             if username != "" {
                                 usernames = username + " " + usernames
                            }
                           }
                           mc.Conn.send <- &message {
                             F: "System",
                             M: usernames,
                           }
                        } else {
			    for c := range h.connections {
				    if c != mc.Conn {
					    select {
					    case c.send <- &mc.Message: //todo

					    default:
						    delete(h.connections, c)
						    close(c.send)
						    go c.ws.Close()
					    }
				    }
                              }
			}
		}
	}
}

type connection struct {
	ws   *websocket.Conn
	send chan *message
}

func (c *connection) reader() {
	for {
		var m message
		if err := websocket.JSON.Receive(c.ws, &m); err != nil {
			fmt.Println(err.Error())
			break
		}
		mc := &messageConnection{Message: m, Conn: c}
		h.recive <- mc
	}
	c.ws.Close()
}

func (c *connection) writer() {
	for m := range c.send {
		if err := websocket.JSON.Send(c.ws, &m); err != nil {
			fmt.Println(err.Error())
			break
		}
	}
	c.ws.Close()
}

func mainServer(w http.ResponseWriter, r *http.Request) {
	title := r.URL.Path[1:]
	if title == "" {
		file, _ := ioutil.ReadFile("index.html")
		w.Write(file)
	} else {
		file, _ := ioutil.ReadFile(title)
		w.Write(file)
	}
}

func webSocketHandler(ws *websocket.Conn) {
	c := &connection{
		send: make(chan *message, 256),
		ws:   ws,
	}
	h.register <- c
	defer func() { h.unregister <- c }()
	go c.writer()
	c.reader()
}

func sourceHandler(w http.ResponseWriter, r *http.Request) {
	http.ServeFile(w, r, r.URL.Path[1:])
}
