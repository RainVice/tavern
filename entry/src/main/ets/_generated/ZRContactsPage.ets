import { ContactsPage } from "../pages/contacts/ContactsPage";

@Builder
function entryContactsPageBuilder(name: string, param?: ESObject) {
  ContactsPage()
}


