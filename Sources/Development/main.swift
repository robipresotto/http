import Core
import Dispatch
import Foundation
import HTTP
import TCP

struct User: Codable {
    var name: String
    var age: Int
}

extension User: MessageCodable {
    static func decode(from message: Message) throws -> User {
        guard message.mediaType == .json else {
            throw "only json supported"
        }

        return try JSONDecoder().decode(User.self, from: message.body.data)
    }

    func encode(to message: Message) throws {
        message.mediaType = .json
        message.body = try Body(JSONEncoder().encode(self))
    }

}

let res = try Response(status: .ok, body: "hi")

struct Application: Responder {
    func respond(to req: Request, using writer: ResponseWriter) {
        // let user = User(name: "Vapor", age: 2)
        // print(String(cString: __dispatch_queue_get_label(nil), encoding: .utf8))
        // try! res.content(user)
        writer.write(res)
    }
}

let app = Application()
let server = try TCP.Server()

server.consume { client in
    let parser = HTTP.RequestParser()
    let serializer = HTTP.ResponseSerializer()

    client.stream(to: parser)
        .stream(to: app.makeStream())
        .stream(to: serializer)
        .consume(into: client)

    client.start()
}

server.errorStream = { error in
    print(error)
}

try server.start(port: 8080)

print("Server started...")

let group = DispatchGroup()
group.enter()
group.wait()
