import { Navigate } from 'react-router-dom'

export function InstructorsScreen() {
  return <Navigate to="/contacts?view=team" replace />
}
