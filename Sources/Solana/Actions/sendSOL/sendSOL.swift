import Foundation

extension Action {
    public func sendSOL(
        to destination: String,
        amount: UInt64,
        signer: Signer,
        onComplete: @escaping ((Result<TransactionID, Error>) -> Void)
    ) {
//        guard let account = try? self.auth.account.get() else {
//            onComplete(.failure(SolanaError.unauthorized))
//            return
//        }
        
        let fromPublicKey = signer.publicKey

//        let fromPublicKey = account.publicKey
        if fromPublicKey.base58EncodedString == destination {
            onComplete(.failure(SolanaError.other("You can not send tokens to yourself")))
            return
        }

        // check
        self.api.getAccountInfo(account: destination, decodedTo: EmptyInfo.self) { resultInfo in

            if case Result.failure( let error) = resultInfo {
                if let solanaError = error as? SolanaError,
                   case SolanaError.couldNotRetriveAccountInfo = solanaError {
                    // let request through
                } else {
                    onComplete(.failure(error))
                    return
                }
            }

            guard case Result.success(let info) = resultInfo else {
                onComplete(.failure(SolanaError.couldNotRetriveAccountInfo))
                return
            }

            guard info.owner == PublicKey.programId.base58EncodedString else {
                onComplete(.failure(SolanaError.other("Invalid account info")))
                return
            }
            guard let to = PublicKey(string: destination) else {
                onComplete(.failure(SolanaError.invalidPublicKey))
                return
            }

            let instruction = SystemProgram.transferInstruction(
                from: fromPublicKey,
                to: to,
                lamports: amount
            )
            self.serializeAndSendWithFee(
                instructions: [instruction],
                signers: [signer]
            ) {
                switch $0 {
                case .success(let transaction):
                    onComplete(.success(transaction))
                case .failure(let error):
                    onComplete(.failure(error))
                }
            }
        }

    }
}

extension ActionTemplates {
    public struct SendSOL: ActionTemplate {
        public init(amount: UInt64, destination: String, signer: Signer) {
            self.amount = amount
            self.destination = destination
            self.signer = signer
        }

        public typealias Success = TransactionID
        public let amount: UInt64
        public let destination: String
        public let signer: Signer

        public func perform(withConfigurationFrom actionClass: Action, completion: @escaping (Result<TransactionID, Error>) -> Void) {
            actionClass.sendSOL(to: destination, amount: amount, signer: signer, onComplete: completion)
        }
    }
}
