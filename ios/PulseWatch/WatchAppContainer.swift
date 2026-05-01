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
                if case .workoutPayload(let p) = msg {
                    await store.receivePayload(p)
                }
            }
        }

        // Drain outbox on .ack from phone.
        Task { [store] in
            await store.bridgeIncomingAcks()
        }

        // Replay any logs that were queued before the watch app died.
        Task { [store] in
            await store.replayOutbox()
        }

        // Recover state if a HKWorkoutSession survived the previous app kill.
        Task { [store] in await store.recoverIfActive() }
    }
}
