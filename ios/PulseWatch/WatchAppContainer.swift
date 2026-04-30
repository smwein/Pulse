import Foundation
import WatchBridge
import WatchWorkout

@MainActor
final class WatchAppContainer {
    let store: WatchSessionStore
    let transport: any WatchSessionTransport

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask)[0]
        let outbox = SetLogOutbox(directory: appSupport)
        let payloadStorage = PayloadFileStorage(directory: appSupport)
        let live = LiveWatchSessionTransport()
        self.transport = live
        let factory: WorkoutSessionFactory = LiveWorkoutSessionFactory()
        self.store = WatchSessionStore(transport: live,
                                       outbox: outbox,
                                       sessionFactory: factory,
                                       payloadStorage: payloadStorage)

        // Bridge incoming payloads from WCSession to the store.
        Task { [store, transport] in
            for await msg in await transport.incoming {
                switch msg {
                case .workoutPayload(let p):
                    await store.receivePayload(p)
                case .setLog(let log):
                    await store.receiveSetLog(log)
                case .sessionLifecycle(let event):
                    await store.receiveLifecycle(event)
                case .ack(let naturalKey):
                    await store.receiveAck(naturalKey: naturalKey)
                }
            }
        }
    }
}
