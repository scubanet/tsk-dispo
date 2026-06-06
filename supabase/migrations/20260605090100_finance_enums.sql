-- 20260605090100_finance_enums.sql
-- Phase-1 — Schritt 2: Enums für die Finanz-Schicht.
--
-- Konvention: zentrale ENUMs wie in 0001. Status-Felder (orders/invoices) bleiben
-- bewusst TEXT + CHECK (jüngere Atoll-Tabellen-Konvention, vgl. elearning_progress).
-- Nur payment_kind ist ein ENUM, weil es die unveränderliche Journal-Semantik hart
-- kodiert (payment/refund/adjustment) — analog movement_kind in 0001.

CREATE TYPE payment_kind AS ENUM (
  'payment',
  'refund',
  'adjustment'
);
