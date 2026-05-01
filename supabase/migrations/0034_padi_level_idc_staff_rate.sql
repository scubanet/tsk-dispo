-- Default-Stundensatz für IDC Staff Instructor (zwischen MSDT 30 und MI 32).
-- Editierbar via SQL oder zukünftiges Settings-UI.

INSERT INTO comp_rates (level, hourly_rate_chf)
SELECT 'IDC Staff', 31.00
WHERE NOT EXISTS (
  SELECT 1 FROM comp_rates WHERE level = 'IDC Staff' AND valid_to IS NULL
);
