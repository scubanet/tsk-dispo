/// Ein angebundenes Konto. Erfüllt eine oder mehrere Capabilities; die
/// konkreten Provider-Instanzen hängen über `AccountConnection` (siehe Hub).
public struct Account: Sendable, Identifiable, Equatable, Hashable {
  public let id: String
  public let type: AccountType
  public let displayName: String
  public let capabilities: Set<Capability>

  public init(id: String, type: AccountType, displayName: String,
              capabilities: Set<Capability>) {
    self.id = id; self.type = type
    self.displayName = displayName; self.capabilities = capabilities
  }

  public func supports(_ capability: Capability) -> Bool {
    capabilities.contains(capability)
  }

  public var ref: AccountRef { AccountRef(accountId: id, type: type) }
}
