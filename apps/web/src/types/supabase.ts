export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      account_movements: {
        Row: {
          amount_chf: number
          breakdown_json: Json | null
          created_at: string
          created_by: string | null
          date: string
          description: string | null
          id: string
          instructor_id: string
          kind: Database["public"]["Enums"]["movement_kind"]
          rate_version: number | null
          ref_assignment_id: string | null
        }
        Insert: {
          amount_chf: number
          breakdown_json?: Json | null
          created_at?: string
          created_by?: string | null
          date: string
          description?: string | null
          id?: string
          instructor_id: string
          kind: Database["public"]["Enums"]["movement_kind"]
          rate_version?: number | null
          ref_assignment_id?: string | null
        }
        Update: {
          amount_chf?: number
          breakdown_json?: Json | null
          created_at?: string
          created_by?: string | null
          date?: string
          description?: string | null
          id?: string
          instructor_id?: string
          kind?: Database["public"]["Enums"]["movement_kind"]
          rate_version?: number | null
          ref_assignment_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "account_movements_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "instructors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "account_movements_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "v_instructor_balance"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "account_movements_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "v_person_pro_tier"
            referencedColumns: ["person_id"]
          },
          {
            foreignKeyName: "account_movements_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "v_saldo_diff"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "account_movements_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "instructors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "account_movements_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_instructor_balance"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "account_movements_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_person_pro_tier"
            referencedColumns: ["person_id"]
          },
          {
            foreignKeyName: "account_movements_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_saldo_diff"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "account_movements_ref_assignment_id_fkey"
            columns: ["ref_assignment_id"]
            isOneToOne: false
            referencedRelation: "course_assignments"
            referencedColumns: ["id"]
          },
        ]
      }
      availability: {
        Row: {
          created_at: string
          from_date: string
          id: string
          instructor_id: string
          kind: Database["public"]["Enums"]["availability_kind"]
          note: string | null
          to_date: string
        }
        Insert: {
          created_at?: string
          from_date: string
          id?: string
          instructor_id: string
          kind: Database["public"]["Enums"]["availability_kind"]
          note?: string | null
          to_date: string
        }
        Update: {
          created_at?: string
          from_date?: string
          id?: string
          instructor_id?: string
          kind?: Database["public"]["Enums"]["availability_kind"]
          note?: string | null
          to_date?: string
        }
        Relationships: [
          {
            foreignKeyName: "availability_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "instructors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "availability_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_instructor_balance"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "availability_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_person_pro_tier"
            referencedColumns: ["person_id"]
          },
          {
            foreignKeyName: "availability_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_saldo_diff"
            referencedColumns: ["instructor_id"]
          },
        ]
      }
      certifications: {
        Row: {
          agency: string
          category: string
          code: string
          created_at: string
          evidence: Json | null
          id: string
          invalidated_at: string | null
          invalidated_reason: string | null
          issued_at: string
          issued_by_name: string | null
          issued_by_person_id: string | null
          issued_by_pro_tier: string | null
          notes: string | null
          number: string | null
          origin: string
          person_id: string
        }
        Insert: {
          agency: string
          category: string
          code: string
          created_at?: string
          evidence?: Json | null
          id?: string
          invalidated_at?: string | null
          invalidated_reason?: string | null
          issued_at: string
          issued_by_name?: string | null
          issued_by_person_id?: string | null
          issued_by_pro_tier?: string | null
          notes?: string | null
          number?: string | null
          origin?: string
          person_id: string
        }
        Update: {
          agency?: string
          category?: string
          code?: string
          created_at?: string
          evidence?: Json | null
          id?: string
          invalidated_at?: string | null
          invalidated_reason?: string | null
          issued_at?: string
          issued_by_name?: string | null
          issued_by_person_id?: string | null
          issued_by_pro_tier?: string | null
          notes?: string | null
          number?: string | null
          origin?: string
          person_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "certifications_issued_by_person_id_fkey"
            columns: ["issued_by_person_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
        ]
      }
      communication_entries: {
        Row: {
          body: string | null
          channel: string
          contact_id: string
          created_at: string
          created_by: string | null
          direction: string
          duration_minutes: number | null
          id: string
          occurred_on: string
          outcome: string | null
          subject: string | null
        }
        Insert: {
          body?: string | null
          channel: string
          contact_id: string
          created_at?: string
          created_by?: string | null
          direction?: string
          duration_minutes?: number | null
          id?: string
          occurred_on?: string
          outcome?: string | null
          subject?: string | null
        }
        Update: {
          body?: string | null
          channel?: string
          contact_id?: string
          created_at?: string
          created_by?: string | null
          direction?: string
          duration_minutes?: number | null
          id?: string
          occurred_on?: string
          outcome?: string | null
          subject?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "communication_entries_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "communication_entries_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "instructors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "communication_entries_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "v_instructor_balance"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "communication_entries_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "v_person_pro_tier"
            referencedColumns: ["person_id"]
          },
          {
            foreignKeyName: "communication_entries_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "v_saldo_diff"
            referencedColumns: ["instructor_id"]
          },
        ]
      }
      comp_rates: {
        Row: {
          created_at: string
          hourly_rate_chf: number
          id: string
          level: Database["public"]["Enums"]["padi_level"]
          rate_version: number
          valid_from: string
          valid_to: string | null
        }
        Insert: {
          created_at?: string
          hourly_rate_chf: number
          id?: string
          level: Database["public"]["Enums"]["padi_level"]
          rate_version?: number
          valid_from?: string
          valid_to?: string | null
        }
        Update: {
          created_at?: string
          hourly_rate_chf?: number
          id?: string
          level?: Database["public"]["Enums"]["padi_level"]
          rate_version?: number
          valid_from?: string
          valid_to?: string | null
        }
        Relationships: []
      }
      comp_units: {
        Row: {
          course_type_id: string
          created_at: string
          id: string
          lake_h: number
          pool_h: number
          role: Database["public"]["Enums"]["assignment_role"]
          theory_h: number
          total_h: number | null
        }
        Insert: {
          course_type_id: string
          created_at?: string
          id?: string
          lake_h?: number
          pool_h?: number
          role: Database["public"]["Enums"]["assignment_role"]
          theory_h?: number
          total_h?: number | null
        }
        Update: {
          course_type_id?: string
          created_at?: string
          id?: string
          lake_h?: number
          pool_h?: number
          role?: Database["public"]["Enums"]["assignment_role"]
          theory_h?: number
          total_h?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "comp_units_course_type_id_fkey"
            columns: ["course_type_id"]
            isOneToOne: false
            referencedRelation: "course_types"
            referencedColumns: ["id"]
          },
        ]
      }
      contact_audit_log: {
        Row: {
          changed_at: string
          changed_by: string | null
          changed_fields: Json | null
          contact_id: string
          id: number
          new_row: Json | null
          old_row: Json | null
          operation: string
          table_name: string
        }
        Insert: {
          changed_at?: string
          changed_by?: string | null
          changed_fields?: Json | null
          contact_id: string
          id?: number
          new_row?: Json | null
          old_row?: Json | null
          operation: string
          table_name: string
        }
        Update: {
          changed_at?: string
          changed_by?: string | null
          changed_fields?: Json | null
          contact_id?: string
          id?: number
          new_row?: Json | null
          old_row?: Json | null
          operation?: string
          table_name?: string
        }
        Relationships: []
      }
      contact_instructor: {
        Row: {
          account_balance: number
          active: boolean
          app_role: Database["public"]["Enums"]["app_role"]
          auth_user_id: string | null
          contact_id: string
          created_at: string
          daily_rate_chf: number | null
          emergency_contact_name: string | null
          emergency_contact_phone: string | null
          hire_date: string | null
          hourly_rate_chf: number | null
          initials: string | null
          notes_internal: string | null
          padi_level: Database["public"]["Enums"]["padi_level"] | null
          padi_pro_number: string | null
          preferred_language: string | null
          termination_date: string | null
          updated_at: string
        }
        Insert: {
          account_balance?: number
          active?: boolean
          app_role?: Database["public"]["Enums"]["app_role"]
          auth_user_id?: string | null
          contact_id: string
          created_at?: string
          daily_rate_chf?: number | null
          emergency_contact_name?: string | null
          emergency_contact_phone?: string | null
          hire_date?: string | null
          hourly_rate_chf?: number | null
          initials?: string | null
          notes_internal?: string | null
          padi_level?: Database["public"]["Enums"]["padi_level"] | null
          padi_pro_number?: string | null
          preferred_language?: string | null
          termination_date?: string | null
          updated_at?: string
        }
        Update: {
          account_balance?: number
          active?: boolean
          app_role?: Database["public"]["Enums"]["app_role"]
          auth_user_id?: string | null
          contact_id?: string
          created_at?: string
          daily_rate_chf?: number | null
          emergency_contact_name?: string | null
          emergency_contact_phone?: string | null
          hire_date?: string | null
          hourly_rate_chf?: number | null
          initials?: string | null
          notes_internal?: string | null
          padi_level?: Database["public"]["Enums"]["padi_level"] | null
          padi_pro_number?: string | null
          preferred_language?: string | null
          termination_date?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "contact_instructor_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: true
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
        ]
      }
      contact_organization: {
        Row: {
          billing_email: string | null
          contact_id: string
          contract_type: string | null
          contract_until: string | null
          created_at: string
          org_kind: string
          parent_org_id: string | null
          payment_terms: string | null
          tax_id: string | null
          updated_at: string
        }
        Insert: {
          billing_email?: string | null
          contact_id: string
          contract_type?: string | null
          contract_until?: string | null
          created_at?: string
          org_kind: string
          parent_org_id?: string | null
          payment_terms?: string | null
          tax_id?: string | null
          updated_at?: string
        }
        Update: {
          billing_email?: string | null
          contact_id?: string
          contract_type?: string | null
          contract_until?: string | null
          created_at?: string
          org_kind?: string
          parent_org_id?: string | null
          payment_terms?: string | null
          tax_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "contact_organization_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: true
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contact_organization_parent_org_id_fkey"
            columns: ["parent_org_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
        ]
      }
      contact_relationships: {
        Row: {
          created_at: string
          ended_at: string | null
          from_contact_id: string
          id: string
          is_primary: boolean
          kind: Database["public"]["Enums"]["relationship_kind"]
          notes: string | null
          role_at_org: string | null
          started_at: string | null
          to_contact_id: string
        }
        Insert: {
          created_at?: string
          ended_at?: string | null
          from_contact_id: string
          id?: string
          is_primary?: boolean
          kind: Database["public"]["Enums"]["relationship_kind"]
          notes?: string | null
          role_at_org?: string | null
          started_at?: string | null
          to_contact_id: string
        }
        Update: {
          created_at?: string
          ended_at?: string | null
          from_contact_id?: string
          id?: string
          is_primary?: boolean
          kind?: Database["public"]["Enums"]["relationship_kind"]
          notes?: string | null
          role_at_org?: string | null
          started_at?: string | null
          to_contact_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "contact_relationships_from_contact_id_fkey"
            columns: ["from_contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contact_relationships_to_contact_id_fkey"
            columns: ["to_contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
        ]
      }
      contact_student: {
        Row: {
          candidate_target_level:
            | Database["public"]["Enums"]["padi_level"]
            | null
          contact_id: string
          created_at: string
          external_brevet_history: Json
          highest_brevet: string | null
          insurance_provider: string | null
          intake_status: string | null
          is_candidate: boolean
          lead_source: string | null
          level: string | null
          medical_clearance_at: string | null
          organization_role: string | null
          photo_url: string | null
          pipeline_stage: string | null
          preferred_language: string | null
          stage_changed_on: string | null
          updated_at: string
        }
        Insert: {
          candidate_target_level?:
            | Database["public"]["Enums"]["padi_level"]
            | null
          contact_id: string
          created_at?: string
          external_brevet_history?: Json
          highest_brevet?: string | null
          insurance_provider?: string | null
          intake_status?: string | null
          is_candidate?: boolean
          lead_source?: string | null
          level?: string | null
          medical_clearance_at?: string | null
          organization_role?: string | null
          photo_url?: string | null
          pipeline_stage?: string | null
          preferred_language?: string | null
          stage_changed_on?: string | null
          updated_at?: string
        }
        Update: {
          candidate_target_level?:
            | Database["public"]["Enums"]["padi_level"]
            | null
          contact_id?: string
          created_at?: string
          external_brevet_history?: Json
          highest_brevet?: string | null
          insurance_provider?: string | null
          intake_status?: string | null
          is_candidate?: boolean
          lead_source?: string | null
          level?: string | null
          medical_clearance_at?: string | null
          organization_role?: string | null
          photo_url?: string | null
          pipeline_stage?: string | null
          preferred_language?: string | null
          stage_changed_on?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "contact_student_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: true
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
        ]
      }
      contacts: {
        Row: {
          addresses: Json
          archived_at: string | null
          birth_date: string | null
          consent_marketing: boolean
          consent_marketing_at: string | null
          consent_marketing_source: string | null
          created_at: string
          created_by: string | null
          display_name: string | null
          emails: Json
          first_name: string | null
          gender: string | null
          id: string
          kind: Database["public"]["Enums"]["contact_kind"]
          languages: string[]
          last_name: string | null
          legal_name: string | null
          merged_into_id: string | null
          notes: string | null
          owner_id: string | null
          phones: Json
          primary_email: string | null
          roles: string[]
          source: string | null
          tags: string[]
          trading_name: string | null
          updated_at: string
        }
        Insert: {
          addresses?: Json
          archived_at?: string | null
          birth_date?: string | null
          consent_marketing?: boolean
          consent_marketing_at?: string | null
          consent_marketing_source?: string | null
          created_at?: string
          created_by?: string | null
          display_name?: string | null
          emails?: Json
          first_name?: string | null
          gender?: string | null
          id?: string
          kind: Database["public"]["Enums"]["contact_kind"]
          languages?: string[]
          last_name?: string | null
          legal_name?: string | null
          merged_into_id?: string | null
          notes?: string | null
          owner_id?: string | null
          phones?: Json
          primary_email?: string | null
          roles?: string[]
          source?: string | null
          tags?: string[]
          trading_name?: string | null
          updated_at?: string
        }
        Update: {
          addresses?: Json
          archived_at?: string | null
          birth_date?: string | null
          consent_marketing?: boolean
          consent_marketing_at?: string | null
          consent_marketing_source?: string | null
          created_at?: string
          created_by?: string | null
          display_name?: string | null
          emails?: Json
          first_name?: string | null
          gender?: string | null
          id?: string
          kind?: Database["public"]["Enums"]["contact_kind"]
          languages?: string[]
          last_name?: string | null
          legal_name?: string | null
          merged_into_id?: string | null
          notes?: string | null
          owner_id?: string | null
          phones?: Json
          primary_email?: string | null
          roles?: string[]
          source?: string | null
          tags?: string[]
          trading_name?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "contacts_merged_into_id_fkey"
            columns: ["merged_into_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contacts_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
        ]
      }
      course_assignments: {
        Row: {
          assigned_for_dates: Json
          confirmed: boolean
          course_id: string
          created_at: string
          id: string
          instructor_id: string
          role: Database["public"]["Enums"]["assignment_role"]
          updated_at: string
        }
        Insert: {
          assigned_for_dates?: Json
          confirmed?: boolean
          course_id: string
          created_at?: string
          id?: string
          instructor_id: string
          role: Database["public"]["Enums"]["assignment_role"]
          updated_at?: string
        }
        Update: {
          assigned_for_dates?: Json
          confirmed?: boolean
          course_id?: string
          created_at?: string
          id?: string
          instructor_id?: string
          role?: Database["public"]["Enums"]["assignment_role"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "course_assignments_course_id_fkey"
            columns: ["course_id"]
            isOneToOne: false
            referencedRelation: "courses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "course_assignments_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "instructors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "course_assignments_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_instructor_balance"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "course_assignments_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_person_pro_tier"
            referencedColumns: ["person_id"]
          },
          {
            foreignKeyName: "course_assignments_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_saldo_diff"
            referencedColumns: ["instructor_id"]
          },
        ]
      }
      course_dates: {
        Row: {
          course_id: string
          created_at: string
          date: string
          has_lake: boolean
          has_pool: boolean
          has_theory: boolean
          id: string
          lake_from: string | null
          lake_to: string | null
          note: string | null
          pool_from: string | null
          pool_location: Database["public"]["Enums"]["pool_location"] | null
          pool_reserved: boolean
          pool_to: string | null
          theory_from: string | null
          theory_to: string | null
          time_from: string | null
          time_to: string | null
          type: Database["public"]["Enums"]["course_date_type"]
        }
        Insert: {
          course_id: string
          created_at?: string
          date: string
          has_lake?: boolean
          has_pool?: boolean
          has_theory?: boolean
          id?: string
          lake_from?: string | null
          lake_to?: string | null
          note?: string | null
          pool_from?: string | null
          pool_location?: Database["public"]["Enums"]["pool_location"] | null
          pool_reserved?: boolean
          pool_to?: string | null
          theory_from?: string | null
          theory_to?: string | null
          time_from?: string | null
          time_to?: string | null
          type?: Database["public"]["Enums"]["course_date_type"]
        }
        Update: {
          course_id?: string
          created_at?: string
          date?: string
          has_lake?: boolean
          has_pool?: boolean
          has_theory?: boolean
          id?: string
          lake_from?: string | null
          lake_to?: string | null
          note?: string | null
          pool_from?: string | null
          pool_location?: Database["public"]["Enums"]["pool_location"] | null
          pool_reserved?: boolean
          pool_to?: string | null
          theory_from?: string | null
          theory_to?: string | null
          time_from?: string | null
          time_to?: string | null
          type?: Database["public"]["Enums"]["course_date_type"]
        }
        Relationships: [
          {
            foreignKeyName: "course_dates_course_id_fkey"
            columns: ["course_id"]
            isOneToOne: false
            referencedRelation: "courses"
            referencedColumns: ["id"]
          },
        ]
      }
      course_participants: {
        Row: {
          certificate_nr: string | null
          certified_by_instructor_id: string | null
          certified_on: string | null
          course_id: string
          enrolled_at: string
          id: string
          notes: string | null
          status: Database["public"]["Enums"]["participant_status"]
          student_id: string
        }
        Insert: {
          certificate_nr?: string | null
          certified_by_instructor_id?: string | null
          certified_on?: string | null
          course_id: string
          enrolled_at?: string
          id?: string
          notes?: string | null
          status?: Database["public"]["Enums"]["participant_status"]
          student_id: string
        }
        Update: {
          certificate_nr?: string | null
          certified_by_instructor_id?: string | null
          certified_on?: string | null
          course_id?: string
          enrolled_at?: string
          id?: string
          notes?: string | null
          status?: Database["public"]["Enums"]["participant_status"]
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "course_participants_certified_by_instructor_id_fkey"
            columns: ["certified_by_instructor_id"]
            isOneToOne: false
            referencedRelation: "instructors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "course_participants_certified_by_instructor_id_fkey"
            columns: ["certified_by_instructor_id"]
            isOneToOne: false
            referencedRelation: "v_instructor_balance"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "course_participants_certified_by_instructor_id_fkey"
            columns: ["certified_by_instructor_id"]
            isOneToOne: false
            referencedRelation: "v_person_pro_tier"
            referencedColumns: ["person_id"]
          },
          {
            foreignKeyName: "course_participants_certified_by_instructor_id_fkey"
            columns: ["certified_by_instructor_id"]
            isOneToOne: false
            referencedRelation: "v_saldo_diff"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "course_participants_course_id_fkey"
            columns: ["course_id"]
            isOneToOne: false
            referencedRelation: "courses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "course_participants_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
        ]
      }
      course_types: {
        Row: {
          active: boolean
          code: string
          created_at: string
          has_elearning: boolean
          id: string
          label: string
          lake_units: number
          notes: string | null
          pool_units: number
          ratio_lake: string | null
          ratio_pool: string | null
          theory_units: number
        }
        Insert: {
          active?: boolean
          code: string
          created_at?: string
          has_elearning?: boolean
          id?: string
          label: string
          lake_units?: number
          notes?: string | null
          pool_units?: number
          ratio_lake?: string | null
          ratio_pool?: string | null
          theory_units?: number
        }
        Update: {
          active?: boolean
          code?: string
          created_at?: string
          has_elearning?: boolean
          id?: string
          label?: string
          lake_units?: number
          notes?: string | null
          pool_units?: number
          ratio_lake?: string | null
          ratio_pool?: string | null
          theory_units?: number
        }
        Relationships: []
      }
      courses: {
        Row: {
          additional_dates: Json
          created_at: string
          created_by: string | null
          id: string
          info: string | null
          location: string | null
          notes: string | null
          num_participants: number
          pool_booked: boolean
          start_date: string
          status: Database["public"]["Enums"]["course_status"]
          title: string
          type_id: string
          updated_at: string
        }
        Insert: {
          additional_dates?: Json
          created_at?: string
          created_by?: string | null
          id?: string
          info?: string | null
          location?: string | null
          notes?: string | null
          num_participants?: number
          pool_booked?: boolean
          start_date: string
          status?: Database["public"]["Enums"]["course_status"]
          title: string
          type_id: string
          updated_at?: string
        }
        Update: {
          additional_dates?: Json
          created_at?: string
          created_by?: string | null
          id?: string
          info?: string | null
          location?: string | null
          notes?: string | null
          num_participants?: number
          pool_booked?: boolean
          start_date?: string
          status?: Database["public"]["Enums"]["course_status"]
          title?: string
          type_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "courses_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "instructors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "courses_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "v_instructor_balance"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "courses_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "v_person_pro_tier"
            referencedColumns: ["person_id"]
          },
          {
            foreignKeyName: "courses_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "v_saldo_diff"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "courses_type_id_fkey"
            columns: ["type_id"]
            isOneToOne: false
            referencedRelation: "course_types"
            referencedColumns: ["id"]
          },
        ]
      }
      device_tokens: {
        Row: {
          apns_token: string
          app_version: string | null
          created_at: string
          device_name: string | null
          id: string
          instructor_id: string
          last_seen: string
          os_version: string | null
          platform: string
        }
        Insert: {
          apns_token: string
          app_version?: string | null
          created_at?: string
          device_name?: string | null
          id?: string
          instructor_id: string
          last_seen?: string
          os_version?: string | null
          platform?: string
        }
        Update: {
          apns_token?: string
          app_version?: string | null
          created_at?: string
          device_name?: string | null
          id?: string
          instructor_id?: string
          last_seen?: string
          os_version?: string | null
          platform?: string
        }
        Relationships: [
          {
            foreignKeyName: "device_tokens_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "instructors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "device_tokens_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_instructor_balance"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "device_tokens_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_person_pro_tier"
            referencedColumns: ["person_id"]
          },
          {
            foreignKeyName: "device_tokens_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_saldo_diff"
            referencedColumns: ["instructor_id"]
          },
        ]
      }
      elearning_progress: {
        Row: {
          completed_on: string | null
          course_code: string
          created_at: string
          id: string
          notes: string | null
          progress_pct: number | null
          started_on: string | null
          status: string
          student_id: string
        }
        Insert: {
          completed_on?: string | null
          course_code: string
          created_at?: string
          id?: string
          notes?: string | null
          progress_pct?: number | null
          started_on?: string | null
          status?: string
          student_id: string
        }
        Update: {
          completed_on?: string | null
          course_code?: string
          created_at?: string
          id?: string
          notes?: string | null
          progress_pct?: number | null
          started_on?: string | null
          status?: string
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "elearning_progress_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
        ]
      }
      import_logs: {
        Row: {
          finished_at: string | null
          id: string
          source_filename: string
          started_at: string
          status: string
          storage_path: string
          summary_json: Json | null
          triggered_by: string | null
        }
        Insert: {
          finished_at?: string | null
          id?: string
          source_filename: string
          started_at?: string
          status: string
          storage_path: string
          summary_json?: Json | null
          triggered_by?: string | null
        }
        Update: {
          finished_at?: string | null
          id?: string
          source_filename?: string
          started_at?: string
          status?: string
          storage_path?: string
          summary_json?: Json | null
          triggered_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "import_logs_triggered_by_fkey"
            columns: ["triggered_by"]
            isOneToOne: false
            referencedRelation: "instructors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "import_logs_triggered_by_fkey"
            columns: ["triggered_by"]
            isOneToOne: false
            referencedRelation: "v_instructor_balance"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "import_logs_triggered_by_fkey"
            columns: ["triggered_by"]
            isOneToOne: false
            referencedRelation: "v_person_pro_tier"
            referencedColumns: ["person_id"]
          },
          {
            foreignKeyName: "import_logs_triggered_by_fkey"
            columns: ["triggered_by"]
            isOneToOne: false
            referencedRelation: "v_saldo_diff"
            referencedColumns: ["instructor_id"]
          },
        ]
      }
      instructor_skills: {
        Row: {
          granted_at: string
          instructor_id: string
          skill_id: string
        }
        Insert: {
          granted_at?: string
          instructor_id: string
          skill_id: string
        }
        Update: {
          granted_at?: string
          instructor_id?: string
          skill_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "instructor_skills_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "instructors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "instructor_skills_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_instructor_balance"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "instructor_skills_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_person_pro_tier"
            referencedColumns: ["person_id"]
          },
          {
            foreignKeyName: "instructor_skills_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_saldo_diff"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "instructor_skills_skill_id_fkey"
            columns: ["skill_id"]
            isOneToOne: false
            referencedRelation: "skills"
            referencedColumns: ["id"]
          },
        ]
      }
      instructors: {
        Row: {
          active: boolean
          auth_user_id: string | null
          calendar_token: string
          color: string
          created_at: string
          email: string | null
          excel_saldo_chf: number | null
          first_name: string
          id: string
          initials: string
          last_name: string
          name: string
          opening_balance_chf: number
          padi_level: Database["public"]["Enums"]["padi_level"]
          padi_nr: string | null
          phone: string | null
          preferred_language: string | null
          role: Database["public"]["Enums"]["app_role"]
          updated_at: string
        }
        Insert: {
          active?: boolean
          auth_user_id?: string | null
          calendar_token: string
          color?: string
          created_at?: string
          email?: string | null
          excel_saldo_chf?: number | null
          first_name?: string
          id?: string
          initials: string
          last_name?: string
          name: string
          opening_balance_chf?: number
          padi_level: Database["public"]["Enums"]["padi_level"]
          padi_nr?: string | null
          phone?: string | null
          preferred_language?: string | null
          role?: Database["public"]["Enums"]["app_role"]
          updated_at?: string
        }
        Update: {
          active?: boolean
          auth_user_id?: string | null
          calendar_token?: string
          color?: string
          created_at?: string
          email?: string | null
          excel_saldo_chf?: number | null
          first_name?: string
          id?: string
          initials?: string
          last_name?: string
          name?: string
          opening_balance_chf?: number
          padi_level?: Database["public"]["Enums"]["padi_level"]
          padi_nr?: string | null
          phone?: string | null
          preferred_language?: string | null
          role?: Database["public"]["Enums"]["app_role"]
          updated_at?: string
        }
        Relationships: []
      }
      intake_checklists: {
        Row: {
          certified_diver_since: string | null
          checked_by_id: string | null
          checked_on: string | null
          course_participant_id: string | null
          created_at: string
          efr_completed_on: string | null
          efr_kind: string | null
          id: string
          id_kind: string | null
          id_seen: boolean
          instructor_status: string | null
          insurance_proof: boolean
          insurance_provider: string | null
          insurance_valid_to: string | null
          liability_signed: boolean
          logbook_dives_count: number | null
          logbook_seen: boolean
          medical_doctor_required: boolean
          medical_doctor_signed: boolean
          medical_notes: string | null
          medical_received: boolean
          medical_signed: boolean
          medical_signed_on: string | null
          min_age_confirmed: boolean
          non_padi_certs_notes: string | null
          non_padi_certs_seen: boolean
          notes: string | null
          safe_diving_signed: boolean
          student_id: string | null
          updated_at: string
        }
        Insert: {
          certified_diver_since?: string | null
          checked_by_id?: string | null
          checked_on?: string | null
          course_participant_id?: string | null
          created_at?: string
          efr_completed_on?: string | null
          efr_kind?: string | null
          id?: string
          id_kind?: string | null
          id_seen?: boolean
          instructor_status?: string | null
          insurance_proof?: boolean
          insurance_provider?: string | null
          insurance_valid_to?: string | null
          liability_signed?: boolean
          logbook_dives_count?: number | null
          logbook_seen?: boolean
          medical_doctor_required?: boolean
          medical_doctor_signed?: boolean
          medical_notes?: string | null
          medical_received?: boolean
          medical_signed?: boolean
          medical_signed_on?: string | null
          min_age_confirmed?: boolean
          non_padi_certs_notes?: string | null
          non_padi_certs_seen?: boolean
          notes?: string | null
          safe_diving_signed?: boolean
          student_id?: string | null
          updated_at?: string
        }
        Update: {
          certified_diver_since?: string | null
          checked_by_id?: string | null
          checked_on?: string | null
          course_participant_id?: string | null
          created_at?: string
          efr_completed_on?: string | null
          efr_kind?: string | null
          id?: string
          id_kind?: string | null
          id_seen?: boolean
          instructor_status?: string | null
          insurance_proof?: boolean
          insurance_provider?: string | null
          insurance_valid_to?: string | null
          liability_signed?: boolean
          logbook_dives_count?: number | null
          logbook_seen?: boolean
          medical_doctor_required?: boolean
          medical_doctor_signed?: boolean
          medical_notes?: string | null
          medical_received?: boolean
          medical_signed?: boolean
          medical_signed_on?: string | null
          min_age_confirmed?: boolean
          non_padi_certs_notes?: string | null
          non_padi_certs_seen?: boolean
          notes?: string | null
          safe_diving_signed?: boolean
          student_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "intake_checklists_checked_by_id_fkey"
            columns: ["checked_by_id"]
            isOneToOne: false
            referencedRelation: "instructors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "intake_checklists_checked_by_id_fkey"
            columns: ["checked_by_id"]
            isOneToOne: false
            referencedRelation: "v_instructor_balance"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "intake_checklists_checked_by_id_fkey"
            columns: ["checked_by_id"]
            isOneToOne: false
            referencedRelation: "v_person_pro_tier"
            referencedColumns: ["person_id"]
          },
          {
            foreignKeyName: "intake_checklists_checked_by_id_fkey"
            columns: ["checked_by_id"]
            isOneToOne: false
            referencedRelation: "v_saldo_diff"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "intake_checklists_course_participant_id_fkey"
            columns: ["course_participant_id"]
            isOneToOne: false
            referencedRelation: "course_participants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "intake_checklists_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
        ]
      }
      padi_skill_records: {
        Row: {
          completed_on: string | null
          course_day_kind: string | null
          course_id: string
          created_at: string
          id: string
          instructor_id: string | null
          notes: string | null
          participant_id: string
          quiz_passed: boolean | null
          skill_code: string
          tg_number: number | null
          updated_at: string
          video_watched: boolean | null
        }
        Insert: {
          completed_on?: string | null
          course_day_kind?: string | null
          course_id: string
          created_at?: string
          id?: string
          instructor_id?: string | null
          notes?: string | null
          participant_id: string
          quiz_passed?: boolean | null
          skill_code: string
          tg_number?: number | null
          updated_at?: string
          video_watched?: boolean | null
        }
        Update: {
          completed_on?: string | null
          course_day_kind?: string | null
          course_id?: string
          created_at?: string
          id?: string
          instructor_id?: string | null
          notes?: string | null
          participant_id?: string
          quiz_passed?: boolean | null
          skill_code?: string
          tg_number?: number | null
          updated_at?: string
          video_watched?: boolean | null
        }
        Relationships: [
          {
            foreignKeyName: "padi_skill_records_course_id_fkey"
            columns: ["course_id"]
            isOneToOne: false
            referencedRelation: "courses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "padi_skill_records_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "instructors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "padi_skill_records_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_instructor_balance"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "padi_skill_records_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_person_pro_tier"
            referencedColumns: ["person_id"]
          },
          {
            foreignKeyName: "padi_skill_records_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_saldo_diff"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "padi_skill_records_participant_id_fkey"
            columns: ["participant_id"]
            isOneToOne: false
            referencedRelation: "course_participants"
            referencedColumns: ["id"]
          },
        ]
      }
      performance_records: {
        Row: {
          assessed_by_id: string | null
          assessed_by_text: string | null
          assessed_on: string | null
          course_date_id: string | null
          course_id: string
          created_at: string
          id: string
          notes: string | null
          pass: boolean | null
          pr_code: string
          score: number | null
          status: string
          student_id: string
          updated_at: string
          with_assistant: boolean | null
        }
        Insert: {
          assessed_by_id?: string | null
          assessed_by_text?: string | null
          assessed_on?: string | null
          course_date_id?: string | null
          course_id: string
          created_at?: string
          id?: string
          notes?: string | null
          pass?: boolean | null
          pr_code: string
          score?: number | null
          status?: string
          student_id: string
          updated_at?: string
          with_assistant?: boolean | null
        }
        Update: {
          assessed_by_id?: string | null
          assessed_by_text?: string | null
          assessed_on?: string | null
          course_date_id?: string | null
          course_id?: string
          created_at?: string
          id?: string
          notes?: string | null
          pass?: boolean | null
          pr_code?: string
          score?: number | null
          status?: string
          student_id?: string
          updated_at?: string
          with_assistant?: boolean | null
        }
        Relationships: [
          {
            foreignKeyName: "performance_records_assessed_by_id_fkey"
            columns: ["assessed_by_id"]
            isOneToOne: false
            referencedRelation: "instructors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "performance_records_assessed_by_id_fkey"
            columns: ["assessed_by_id"]
            isOneToOne: false
            referencedRelation: "v_instructor_balance"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "performance_records_assessed_by_id_fkey"
            columns: ["assessed_by_id"]
            isOneToOne: false
            referencedRelation: "v_person_pro_tier"
            referencedColumns: ["person_id"]
          },
          {
            foreignKeyName: "performance_records_assessed_by_id_fkey"
            columns: ["assessed_by_id"]
            isOneToOne: false
            referencedRelation: "v_saldo_diff"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "performance_records_course_date_id_fkey"
            columns: ["course_date_id"]
            isOneToOne: false
            referencedRelation: "course_dates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "performance_records_course_id_fkey"
            columns: ["course_id"]
            isOneToOne: false
            referencedRelation: "courses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "performance_records_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
        ]
      }
      pool_bookings: {
        Row: {
          course_id: string | null
          created_at: string
          date: string
          id: string
          location: Database["public"]["Enums"]["pool_location"]
          note: string | null
          time_from: string | null
          time_to: string | null
        }
        Insert: {
          course_id?: string | null
          created_at?: string
          date: string
          id?: string
          location: Database["public"]["Enums"]["pool_location"]
          note?: string | null
          time_from?: string | null
          time_to?: string | null
        }
        Update: {
          course_id?: string | null
          created_at?: string
          date?: string
          id?: string
          location?: Database["public"]["Enums"]["pool_location"]
          note?: string | null
          time_from?: string | null
          time_to?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "pool_bookings_course_id_fkey"
            columns: ["course_id"]
            isOneToOne: false
            referencedRelation: "courses"
            referencedColumns: ["id"]
          },
        ]
      }
      pr_catalogs: {
        Row: {
          active: boolean
          course_type: string
          created_at: string
          data: Json
          id: string
          language: string
          version: string
        }
        Insert: {
          active?: boolean
          course_type: string
          created_at?: string
          data: Json
          id?: string
          language?: string
          version: string
        }
        Update: {
          active?: boolean
          course_type?: string
          created_at?: string
          data?: Json
          id?: string
          language?: string
          version?: string
        }
        Relationships: []
      }
      skill_definitions: {
        Row: {
          course_day_kind: string | null
          course_type_code: string
          created_at: string
          display_order: number
          has_date: boolean
          has_quiz: boolean
          has_tg_number: boolean
          has_video: boolean
          id: string
          label_de: string
          label_en: string
          section: string
          skill_code: string
          tg_number_options: number[] | null
        }
        Insert: {
          course_day_kind?: string | null
          course_type_code: string
          created_at?: string
          display_order?: number
          has_date?: boolean
          has_quiz?: boolean
          has_tg_number?: boolean
          has_video?: boolean
          id?: string
          label_de: string
          label_en: string
          section: string
          skill_code: string
          tg_number_options?: number[] | null
        }
        Update: {
          course_day_kind?: string | null
          course_type_code?: string
          created_at?: string
          display_order?: number
          has_date?: boolean
          has_quiz?: boolean
          has_tg_number?: boolean
          has_video?: boolean
          id?: string
          label_de?: string
          label_en?: string
          section?: string
          skill_code?: string
          tg_number_options?: number[] | null
        }
        Relationships: []
      }
      skills: {
        Row: {
          category: string | null
          code: string
          created_at: string
          id: string
          label: string
        }
        Insert: {
          category?: string | null
          code: string
          created_at?: string
          id?: string
          label: string
        }
        Update: {
          category?: string | null
          code?: string
          created_at?: string
          id?: string
          label?: string
        }
        Relationships: []
      }
      student_certifications: {
        Row: {
          certificate_nr: string | null
          certification: string
          created_at: string
          id: string
          issued_by: string | null
          issued_date: string | null
          notes: string | null
          student_id: string
        }
        Insert: {
          certificate_nr?: string | null
          certification: string
          created_at?: string
          id?: string
          issued_by?: string | null
          issued_date?: string | null
          notes?: string | null
          student_id: string
        }
        Update: {
          certificate_nr?: string | null
          certification?: string
          created_at?: string
          id?: string
          issued_by?: string | null
          issued_date?: string | null
          notes?: string | null
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "student_certifications_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      v_course_participant_count: {
        Row: {
          certified_count: number | null
          course_id: string | null
          dropped_count: number | null
          enrolled_count: number | null
          total_count: number | null
        }
        Relationships: [
          {
            foreignKeyName: "course_participants_course_id_fkey"
            columns: ["course_id"]
            isOneToOne: false
            referencedRelation: "courses"
            referencedColumns: ["id"]
          },
        ]
      }
      v_instructor_balance: {
        Row: {
          balance_chf: number | null
          instructor_id: string | null
          last_movement_date: string | null
          movement_count: number | null
          name: string | null
          padi_level: Database["public"]["Enums"]["padi_level"] | null
        }
        Relationships: []
      }
      v_instructor_certifications_by_level: {
        Row: {
          count: number | null
          instructor_id: string | null
          level_code: string | null
          level_label: string | null
          most_recent: string | null
        }
        Relationships: [
          {
            foreignKeyName: "course_participants_certified_by_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "instructors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "course_participants_certified_by_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_instructor_balance"
            referencedColumns: ["instructor_id"]
          },
          {
            foreignKeyName: "course_participants_certified_by_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_person_pro_tier"
            referencedColumns: ["person_id"]
          },
          {
            foreignKeyName: "course_participants_certified_by_instructor_id_fkey"
            columns: ["instructor_id"]
            isOneToOne: false
            referencedRelation: "v_saldo_diff"
            referencedColumns: ["instructor_id"]
          },
        ]
      }
      v_person_pro_tier: {
        Row: {
          name: string | null
          person_id: string | null
          pro_tier: string | null
        }
        Insert: {
          name?: string | null
          person_id?: string | null
          pro_tier?: never
        }
        Update: {
          name?: string | null
          person_id?: string | null
          pro_tier?: never
        }
        Relationships: []
      }
      v_saldo_diff: {
        Row: {
          app_balance: number | null
          diff: number | null
          excel_saldo: number | null
          instructor_id: string | null
          name: string | null
        }
        Relationships: []
      }
    }
    Functions: {
      calc_compensation: { Args: { p_assignment_id: string }; Returns: Json }
      cockpit_data: { Args: { p_end: string; p_start: string }; Returns: Json }
      conflict_check: {
        Args: { p_dates: string[]; p_instructor_id: string }
        Returns: {
          conflict_dates: string[]
          conflicting_course_id: string
          conflicting_course_title: string
          conflicting_role: Database["public"]["Enums"]["assignment_role"]
        }[]
      }
      current_instructor: {
        Args: never
        Returns: {
          active: boolean
          auth_user_id: string | null
          calendar_token: string
          color: string
          created_at: string
          email: string | null
          excel_saldo_chf: number | null
          first_name: string
          id: string
          initials: string
          last_name: string
          name: string
          opening_balance_chf: number
          padi_level: Database["public"]["Enums"]["padi_level"]
          padi_nr: string | null
          phone: string | null
          preferred_language: string | null
          role: Database["public"]["Enums"]["app_role"]
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "instructors"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      current_rate: {
        Args: { p_level: Database["public"]["Enums"]["padi_level"] }
        Returns: number
      }
      find_potential_duplicates: {
        Args: { p_contact_id: string }
        Returns: {
          candidate_id: string
          display_name: string
          match_reason: string
        }[]
      }
      gdpr_anonymize_contact: {
        Args: { p_contact_id: string }
        Returns: undefined
      }
      is_cd: { Args: never; Returns: boolean }
      is_dispatcher: { Args: never; Returns: boolean }
      is_owner: { Args: never; Returns: boolean }
      is_owner_or_dispatcher: { Args: never; Returns: boolean }
      merge_contacts: {
        Args: { p_loser: string; p_winner: string }
        Returns: undefined
      }
      recalc_all_compensations: {
        Args: never
        Returns: {
          deleted_count: number
          inserted_count: number
        }[]
      }
      skill_match: {
        Args: { p_for_dates: string[]; p_skill_codes: string[] }
        Returns: {
          has_conflict: boolean
          instructor_id: string
          last_assigned: string
          name: string
          padi_level: Database["public"]["Enums"]["padi_level"]
        }[]
      }
      student_upsert: {
        Args: {
          p_contact: Json
          p_contact_id: string
          p_org_id?: string
          p_student: Json
        }
        Returns: string
      }
    }
    Enums: {
      app_role: "dispatcher" | "instructor" | "owner" | "cd"
      assignment_role: "haupt" | "assist" | "dmt" | "opfer"
      availability_kind: "urlaub" | "abwesend" | "verfügbar"
      contact_kind: "person" | "organization"
      course_date_type: "theorie" | "pool" | "see"
      course_status: "confirmed" | "tentative" | "cancelled" | "completed"
      movement_kind: "vergütung" | "übertrag" | "korrektur"
      padi_level:
        | "Instructor"
        | "Staff Instructor"
        | "DM"
        | "Shop Staff"
        | "Andere Funktion"
        | "AI"
        | "OWSI"
        | "MSDT"
        | "MI"
        | "CD"
        | "Andere"
        | "IDC Staff"
      participant_status: "enrolled" | "certified" | "dropped"
      pool_location: "mooesli" | "langnau" | "kloten" | "uitikon"
      relationship_kind:
        | "works_at"
        | "owns"
        | "spouse_of"
        | "child_of"
        | "parent_of"
        | "referred_by"
        | "subsidiary_of"
        | "partner_of"
        | "supplier_of"
        | "student_of"
        | "mentor_of"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["dispatcher", "instructor", "owner", "cd"],
      assignment_role: ["haupt", "assist", "dmt", "opfer"],
      availability_kind: ["urlaub", "abwesend", "verfügbar"],
      contact_kind: ["person", "organization"],
      course_date_type: ["theorie", "pool", "see"],
      course_status: ["confirmed", "tentative", "cancelled", "completed"],
      movement_kind: ["vergütung", "übertrag", "korrektur"],
      padi_level: [
        "Instructor",
        "Staff Instructor",
        "DM",
        "Shop Staff",
        "Andere Funktion",
        "AI",
        "OWSI",
        "MSDT",
        "MI",
        "CD",
        "Andere",
        "IDC Staff",
      ],
      participant_status: ["enrolled", "certified", "dropped"],
      pool_location: ["mooesli", "langnau", "kloten", "uitikon"],
      relationship_kind: [
        "works_at",
        "owns",
        "spouse_of",
        "child_of",
        "parent_of",
        "referred_by",
        "subsidiary_of",
        "partner_of",
        "supplier_of",
        "student_of",
        "mentor_of",
      ],
    },
  },
} as const
