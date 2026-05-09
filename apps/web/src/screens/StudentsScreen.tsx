import { Navigate } from 'react-router-dom'

export function StudentsScreen() {
  return <Navigate to="/contacts?view=students" replace />
}
