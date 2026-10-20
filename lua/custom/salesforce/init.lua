-- Salesforce workspace setup.
--
-- Keep Salesforce-specific modules here so they stay out of the global config
-- and only load when an SFDX project is detected.

return require 'custom.salesforce.apex'
