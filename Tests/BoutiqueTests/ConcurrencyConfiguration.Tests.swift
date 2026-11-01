import Boutique
import Testing

@Test nonisolated func keychainValuesRemainUsableOutsideMainActor() {
    let service = KeychainService(value: "service")
    let group = KeychainGroup(value: "group")
    let literalService: KeychainService = "service"
    let literalGroup: KeychainGroup = "group"
    _ = (service.value, group.value, literalService.value, literalGroup.value)
}
