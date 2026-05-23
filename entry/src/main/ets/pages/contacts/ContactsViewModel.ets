import { RouterName, RVRouter } from 'router'

export class ContactsViewModel {
  onAdd() {
    RVRouter.push(RouterName.AddContacts)
  }
}