import Foundation
import AtollCore
import AtollHub
import Supabase

/// Erfuellt `ContactsProvider` ueber die Atoll-`contacts`-Tabelle. RLS ist fuer
/// `contacts` permissiv (alle authentifizierten Nutzer lesen alle Kontakte);
/// wir filtern auf aktive, nicht zusammengefuehrte Personen/Orgs. Spaltenliste
/// gespiegelt vom Web-`contactQueries.ts` (Subset).
struct AtollContactsAdapter: ContactsProvider {
  let accountId: String
  let pageSize: Int

  init(accountId: String = "atoll", pageSize: Int = 1000) {
    self.accountId = accountId
    self.pageSize = pageSize
  }

  func contacts() async throws -> [UnifiedContact] {
    let rows: [AtollContactRow] = try await SupabaseClient.shared
      .from("contacts")
      .select("id, kind, first_name, last_name, trading_name, legal_name, primary_email, emails, phones, birth_date, addresses, languages, roles, tags, notes")
      .is("archived_at", value: nil as Bool?)
      .is("merged_into_id", value: nil as Bool?)
      .order("last_name", ascending: true)
      .limit(pageSize)
      .execute()
      .value

    return AtollContactMapper.contacts(from: rows, accountId: accountId)
  }
}
