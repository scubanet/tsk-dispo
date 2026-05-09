import { Navigate } from 'react-router-dom'

export function CDOrganizationsScreen() {
  return <Navigate to="/contacts?view=orgs" replace />
}
