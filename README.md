# SSHTunnel

SSHTunnel is a framework for development tools to allow secure remote access to your server resources. Frequently a tool for development, such as a MySQL client, might need access to a service that isn't accessible to the outside world for security reasons. If you're creating such an app, integrating SSHTunnel allows the user to create a secure tunnel to their server, accessing it as though they're logged in locally. You simply give it the address of the server, the port you'd like to connect to, and your SSH authentication data, and SSHTunnel will return a port number. Tell your app to connect to that port on `localhost`, and presto! You have an encrypted tunnel to your service.

This code is obviously very early, and any bug fixes/gaping security holes/code improvements are appreciated.

#### Known bugs/planned fixes

- Error handling
- Fix inevitable memory leaks that I missed
- Get rid of `select()`, fix multithreaded connection code
- Refactor more C code into C `struct` extensions
- CocoaPods/Carthage/SwiftPM support
- Switch to `libssh` (`libssh2` is very nice but lacks advanced cert support)