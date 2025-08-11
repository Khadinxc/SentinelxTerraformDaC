| Wiki Information | Overview Statistics | Severity Distribution |
|------------------|---------------------|----------------------|
| **Status:** Auto-generated from manifest<br/>**Environment:** development<br/>**Generated:** 2025-08-04 20:59:04 UTC<br/>**Repository:** [github.com/Khadinxc/Sentinel-CICD-Detections](https://github.com/Khadinxc/SentinelxTerraform-DaC)<br/>**Branch:** main<br/>**Total Rules:** 12 | **Total Rules:** 12 (100%)<br/>**Enabled:** 11 (91.7%)<br/>**Disabled:** 16 (133.3%) | **High:** 4 (HIGH)<br/>**Medium:** 16 (MED)<br/>**Low:** 16 (LOW)<br/>**Informational:** 0 (INFO) |

## MITRE ATT&CK Coverage

**Coverage Summary:**
- **Tactics Covered:** 7 of 14 MITRE ATT&CK tactics
- **Enabled Rules:** 11
- **Techniques Covered:** 8
- **Coverage Density:** 0.73 techniques per enabled rule

| Metric | **Reconnaissance** | **ResourceDevelopment** | **InitialAccess** | **Execution** | **Persistence** | **PrivilegeEscalation** | **DefenseEvasion** | **CredentialAccess** | **Discovery** | **LateralMovement** | **Collection** | **CommandAndControl** | **Exfiltration** | **Impact** |
|--------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|
| **Rules** | 0 | 0 | 2 | 1 | 2 | 2 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 |
| **Top Techniques** | Nil | Nil | T1078 +2 more | T1027 +1 more | T1078 +1 more | T1078 +1 more | T1027 +1 more | T1078 +1 more | Nil | Nil | Nil | Nil | Nil | Nil |

---

## All Detection Rules

| Rule Name | Kind | Severity | Status | Tactics | Techniques | Links |
|-----------|------|----------|--------|---------|------------|-------|
| **[Large Data Download Detection](#DetectionRulesWiki-LargeDataDownloadDetection)** | 📊 Scheduled | [MED] | DISABLED | Exfiltration | T1041 | [GitHub](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FLarge%20Data%20Download%20Detection.yaml) |
| **[Accessed files shared by temporary external user](#DetectionRulesWiki-Accessedfilessharedbytemporaryexternaluser)** | 📊 Scheduled | [LOW] | ENABLED | InitialAccess | T1566 | [GitHub](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FAccessed%20files%20shared%20by%20temporary%20external%20user.yaml) |
| **[Microsoft Defender for Identity](#DetectionRulesWiki-MicrosoftDefenderforIdentity)** | 🛡️ Microsoft | _Inherited from source_ | ENABLED | _Determined by underlying alerts_ | _Determined by underlying alerts_ | [GitHub](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FMicrosoft%20Defender%20for%20Identity.yaml) |
| **[Critical Admin Activity Detection](#DetectionRulesWiki-CriticalAdminActivityDetection)** | ⚡ NRT | [HIGH] | ENABLED | PrivilegeEscalation, Persistence | T1078, T1098 | [GitHub](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FCritical%20Admin%20Activity%20Detection.yaml) |
| **[Microsoft Defender for Endpoint](#DetectionRulesWiki-MicrosoftDefenderforEndpoint)** | 🛡️ Microsoft | _Inherited from source_ | ENABLED | _Determined by underlying alerts_ | _Determined by underlying alerts_ | [GitHub](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FMicrosoft%20Defender%20for%20Endpoint.yaml) |
| **[Privilege Escalation Detection](#DetectionRulesWiki-PrivilegeEscalationDetection)** | 📊 Scheduled | [HIGH] | ENABLED | PrivilegeEscalation, Persistence | T1078, T1098 | [GitHub](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FPrivilege%20Escalation%20Detection.yaml) |
| **[Microsoft Defender for Cloud](#DetectionRulesWiki-MicrosoftDefenderforCloud)** | 🛡️ Microsoft | _Inherited from source_ | ENABLED | _Determined by underlying alerts_ | _Determined by underlying alerts_ | [GitHub](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FMicrosoft%20Defender%20for%20Cloud.yaml) |
| **[Microsoft Defender for Cloud Apps - High Severity](#DetectionRulesWiki-MicrosoftDefenderforCloudAppsHighSeverity)** | 🛡️ Microsoft | _Inherited from source_ | ENABLED | _Determined by underlying alerts_ | _Determined by underlying alerts_ | [GitHub](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FMicrosoft%20Defender%20for%20Cloud%20Apps%20-%20High%20Severity.yaml) |
| **[Malware Detection from Defender](#DetectionRulesWiki-MalwareDetectionfromDefender)** | 📊 Scheduled | [HIGH] | ENABLED | Execution, DefenseEvasion | T1059, T1027 | [GitHub](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FMalware%20Detection%20from%20Defender.yaml) |
| **[Suspicious Login Activity Detection](#DetectionRulesWiki-SuspiciousLoginActivityDetection)** | 📊 Scheduled | [HIGH] | ENABLED | CredentialAccess, InitialAccess | T1110, T1078 | [GitHub](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FSuspicious%20Login%20Activity%20Detection.yaml) |
| **[Advanced Multistage Attack Detection v3](#DetectionRulesWiki-AdvancedMultistageAttackDetectionv3)** | 🤖 Fusion | _Dynamic (ML-based)_ | ENABLED | _ML-based correlation_ | _ML-based correlation_ | [GitHub](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FAdvanced%20Multistage%20Attack%20Detection%20v3.yaml) |
| **[Microsoft Defender for Office 365](#DetectionRulesWiki-MicrosoftDefenderforOffice365)** | 🛡️ Microsoft | _Inherited from source_ | ENABLED | _Determined by underlying alerts_ | _Determined by underlying alerts_ | [GitHub](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FMicrosoft%20Defender%20for%20Office%20365.yaml) |

---

## Detailed Rule Information

<h3 id="DetectionRulesWiki-LargeDataDownloadDetection">Large Data Download Detection</h3>

| Field | Value |
|-------|-------|
| **Status** | DISABLED |
| **Severity** | Medium |
| **Source** | **[View Source](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FLarge%20Data%20Download%20Detection.yaml)** |

<h4 id="DetectionRulesWiki-LargeDataDownloadDetection-Description">Description</h4>
Detects unusually large data downloads that may indicate data exfiltration

<h4 id="DetectionRulesWiki-LargeDataDownloadDetection-RuleDetails">Rule Details</h4>

| Property | Value |
|----------|-------|
| **Rule Type** | Scheduled Analytics Rule |
| **Query Period** | PT1H |
| **Query Frequency** | PT1H |
| **Trigger Operator** | GreaterThan |

<h4 id="DetectionRulesWiki-LargeDataDownloadDetection-MITREMapping">MITRE ATT&CK Mapping</h4>

| Category | Value |
|----------|-------|
| **Tactics** | Exfiltration |
| **Techniques** | [T1041](https://attack.mitre.org/techniques/T1041/) |

<h4 id="DetectionRulesWiki-LargeDataDownloadDetection-EntityMappings">Entity Mappings</h4>

- **Account:** FullName -> UserId

---

<h3 id="DetectionRulesWiki-Accessedfilessharedbytemporaryexternaluser">Accessed files shared by temporary external user</h3>

| Field | Value |
|-------|-------|
| **Status** | ENABLED |
| **Severity** | Low |
| **Source** | **[View Source](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FAccessed%20files%20shared%20by%20temporary%20external%20user.yaml)** |

<h4 id="DetectionRulesWiki-Accessedfilessharedbytemporaryexternaluser-Description">Description</h4>
This detection identifies when an external user is added to a Team or Teams chat and shares a file which is accessed by many users (>10) and the users is removed within short period of time. This might be an indicator of suspicious activity.

<h4 id="DetectionRulesWiki-Accessedfilessharedbytemporaryexternaluser-RuleDetails">Rule Details</h4>

| Property | Value |
|----------|-------|
| **Rule Type** | Scheduled Analytics Rule |
| **Query Period** | PT1H |
| **Query Frequency** | PT1H |
| **Trigger Operator** | GreaterThan |

<h4 id="DetectionRulesWiki-Accessedfilessharedbytemporaryexternaluser-MITREMapping">MITRE ATT&CK Mapping</h4>

| Category | Value |
|----------|-------|
| **Tactics** | InitialAccess |
| **Techniques** | [T1566](https://attack.mitre.org/techniques/T1566/) |

<h4 id="DetectionRulesWiki-Accessedfilessharedbytemporaryexternaluser-EntityMappings">Entity Mappings</h4>

- **Account:** FullName -> MemberAdded, Name -> MemberAddedAccountName, UPNSuffix -> MemberAddedAccountUPNSuffix
- **Account:** FullName -> UserWhoAdded, Name -> UserWhoAddedAccountName, UPNSuffix -> UserWhoAddedAccountUPNSuffix
- **Account:** FullName -> UserWhoDeleted, Name -> UserWhoDeletedAccountName, UPNSuffix -> UserWhoDeletedAccountUPNSuffix
- **IP:** Address -> ClientIP

---

<h3 id="DetectionRulesWiki-MicrosoftDefenderforIdentity">Microsoft Defender for Identity</h3>

| Field | Value |
|-------|-------|
| **Status** | ENABLED |
| **Severity** | _Inherited from source_ |
| **Source** | **[View Source](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FMicrosoft%20Defender%20for%20Identity.yaml)** |

<h4 id="DetectionRulesWiki-MicrosoftDefenderforIdentity-Description">Description</h4>
Creates incidents for alerts from Microsoft Defender for Identity

<h4 id="DetectionRulesWiki-MicrosoftDefenderforIdentity-RuleDetails">Rule Details</h4>

| Property | Value |
|----------|-------|
| **Rule Type** | Microsoft Security Product Integration |
| **Data Source** | Microsoft Security Products |
| **Processing** | Automatic incident creation from product alerts |
| **Product Filter** | Azure Advanced Threat Protection |

<h4 id="DetectionRulesWiki-MicrosoftDefenderforIdentity-MITREMapping">MITRE ATT&CK Mapping</h4>

| Category | Value |
|----------|-------|
| **Tactics** | _Determined by underlying alerts_ |
| **Techniques** | _Determined by underlying Microsoft security product alerts_ |

<h4 id="DetectionRulesWiki-MicrosoftDefenderforIdentity-EntityMappings">Entity Mappings</h4>

- _Entity mappings are inherited from the underlying Microsoft security product alerts_

---

<h3 id="DetectionRulesWiki-CriticalAdminActivityDetection">Critical Admin Activity Detection</h3>

| Field | Value |
|-------|-------|
| **Status** | ENABLED |
| **Severity** | High |
| **Source** | **[View Source](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FCritical%20Admin%20Activity%20Detection.yaml)** |

<h4 id="DetectionRulesWiki-CriticalAdminActivityDetection-Description">Description</h4>
Near real-time detection of critical administrative activities that require immediate attention

<h4 id="DetectionRulesWiki-CriticalAdminActivityDetection-RuleDetails">Rule Details</h4>

| Property | Value |
|----------|-------|
| **Rule Type** | Near Real-Time (NRT) Analytics Rule |
| **Processing** | Near real-time analysis |

<h4 id="DetectionRulesWiki-CriticalAdminActivityDetection-MITREMapping">MITRE ATT&CK Mapping</h4>

| Category | Value |
|----------|-------|
| **Tactics** | PrivilegeEscalation, Persistence |
| **Techniques** | [T1078](https://attack.mitre.org/techniques/T1078/), [T1098](https://attack.mitre.org/techniques/T1098/) |

<h4 id="DetectionRulesWiki-CriticalAdminActivityDetection-EntityMappings">Entity Mappings</h4>

- **Account:** Name -> Caller
- **IP:** Address -> CallerIpAddress

---

<h3 id="DetectionRulesWiki-MicrosoftDefenderforEndpoint">Microsoft Defender for Endpoint</h3>

| Field | Value |
|-------|-------|
| **Status** | ENABLED |
| **Severity** | _Inherited from source_ |
| **Source** | **[View Source](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FMicrosoft%20Defender%20for%20Endpoint.yaml)** |

<h4 id="DetectionRulesWiki-MicrosoftDefenderforEndpoint-Description">Description</h4>
Creates incidents for alerts from Microsoft Defender for Endpoint

<h4 id="DetectionRulesWiki-MicrosoftDefenderforEndpoint-RuleDetails">Rule Details</h4>

| Property | Value |
|----------|-------|
| **Rule Type** | Microsoft Security Product Integration |
| **Data Source** | Microsoft Security Products |
| **Processing** | Automatic incident creation from product alerts |
| **Product Filter** | Microsoft Defender Advanced Threat Protection |

<h4 id="DetectionRulesWiki-MicrosoftDefenderforEndpoint-MITREMapping">MITRE ATT&CK Mapping</h4>

| Category | Value |
|----------|-------|
| **Tactics** | _Determined by underlying alerts_ |
| **Techniques** | _Determined by underlying Microsoft security product alerts_ |

<h4 id="DetectionRulesWiki-MicrosoftDefenderforEndpoint-EntityMappings">Entity Mappings</h4>

- _Entity mappings are inherited from the underlying Microsoft security product alerts_

---

<h3 id="DetectionRulesWiki-PrivilegeEscalationDetection">Privilege Escalation Detection</h3>

| Field | Value |
|-------|-------|
| **Status** | ENABLED |
| **Severity** | High |
| **Source** | **[View Source](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FPrivilege%20Escalation%20Detection.yaml)** |

<h4 id="DetectionRulesWiki-PrivilegeEscalationDetection-Description">Description</h4>
Detects potential privilege escalation activities in Azure AD

<h4 id="DetectionRulesWiki-PrivilegeEscalationDetection-RuleDetails">Rule Details</h4>

| Property | Value |
|----------|-------|
| **Rule Type** | Scheduled Analytics Rule |
| **Query Period** | PT1H |
| **Query Frequency** | PT1H |
| **Trigger Operator** | GreaterThan |

<h4 id="DetectionRulesWiki-PrivilegeEscalationDetection-MITREMapping">MITRE ATT&CK Mapping</h4>

| Category | Value |
|----------|-------|
| **Tactics** | PrivilegeEscalation, Persistence |
| **Techniques** | [T1078](https://attack.mitre.org/techniques/T1078/), [T1098](https://attack.mitre.org/techniques/T1098/) |

<h4 id="DetectionRulesWiki-PrivilegeEscalationDetection-EntityMappings">Entity Mappings</h4>

- **Account:** FullName -> InitiatedBy
- **Account:** FullName -> TargetUser

---

<h3 id="DetectionRulesWiki-MicrosoftDefenderforCloud">Microsoft Defender for Cloud</h3>

| Field | Value |
|-------|-------|
| **Status** | ENABLED |
| **Severity** | _Inherited from source_ |
| **Source** | **[View Source](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FMicrosoft%20Defender%20for%20Cloud.yaml)** |

<h4 id="DetectionRulesWiki-MicrosoftDefenderforCloud-Description">Description</h4>
Creates incidents for alerts from Microsoft Defender for Cloud

<h4 id="DetectionRulesWiki-MicrosoftDefenderforCloud-RuleDetails">Rule Details</h4>

| Property | Value |
|----------|-------|
| **Rule Type** | Microsoft Security Product Integration |
| **Data Source** | Microsoft Security Products |
| **Processing** | Automatic incident creation from product alerts |
| **Product Filter** | Azure Security Center |

<h4 id="DetectionRulesWiki-MicrosoftDefenderforCloud-MITREMapping">MITRE ATT&CK Mapping</h4>

| Category | Value |
|----------|-------|
| **Tactics** | _Determined by underlying alerts_ |
| **Techniques** | _Determined by underlying Microsoft security product alerts_ |

<h4 id="DetectionRulesWiki-MicrosoftDefenderforCloud-EntityMappings">Entity Mappings</h4>

- _Entity mappings are inherited from the underlying Microsoft security product alerts_

---

<h3 id="DetectionRulesWiki-MicrosoftDefenderforCloudAppsHighSeverity">Microsoft Defender for Cloud Apps - High Severity</h3>

| Field | Value |
|-------|-------|
| **Status** | ENABLED |
| **Severity** | _Inherited from source_ |
| **Source** | **[View Source](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FMicrosoft%20Defender%20for%20Cloud%20Apps%20-%20High%20Severity.yaml)** |

<h4 id="DetectionRulesWiki-MicrosoftDefenderforCloudAppsHighSeverity-Description">Description</h4>
Creates incidents for high severity alerts from Microsoft Defender for Cloud Apps

<h4 id="DetectionRulesWiki-MicrosoftDefenderforCloudAppsHighSeverity-RuleDetails">Rule Details</h4>

| Property | Value |
|----------|-------|
| **Rule Type** | Microsoft Security Product Integration |
| **Data Source** | Microsoft Security Products |
| **Processing** | Automatic incident creation from product alerts |
| **Product Filter** | Microsoft Cloud App Security |

<h4 id="DetectionRulesWiki-MicrosoftDefenderforCloudAppsHighSeverity-MITREMapping">MITRE ATT&CK Mapping</h4>

| Category | Value |
|----------|-------|
| **Tactics** | _Determined by underlying alerts_ |
| **Techniques** | _Determined by underlying Microsoft security product alerts_ |

<h4 id="DetectionRulesWiki-MicrosoftDefenderforCloudAppsHighSeverity-EntityMappings">Entity Mappings</h4>

- _Entity mappings are inherited from the underlying Microsoft security product alerts_

---

<h3 id="DetectionRulesWiki-MalwareDetectionfromDefender">Malware Detection from Defender</h3>

| Field | Value |
|-------|-------|
| **Status** | ENABLED |
| **Severity** | High |
| **Source** | **[View Source](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FMalware%20Detection%20from%20Defender.yaml)** |

<h4 id="DetectionRulesWiki-MalwareDetectionfromDefender-Description">Description</h4>
Detects malware alerts from Microsoft Defender

<h4 id="DetectionRulesWiki-MalwareDetectionfromDefender-RuleDetails">Rule Details</h4>

| Property | Value |
|----------|-------|
| **Rule Type** | Scheduled Analytics Rule |
| **Query Period** | PT1H |
| **Query Frequency** | PT1H |
| **Trigger Operator** | GreaterThan |

<h4 id="DetectionRulesWiki-MalwareDetectionfromDefender-MITREMapping">MITRE ATT&CK Mapping</h4>

| Category | Value |
|----------|-------|
| **Tactics** | Execution, DefenseEvasion |
| **Techniques** | [T1059](https://attack.mitre.org/techniques/T1059/), [T1027](https://attack.mitre.org/techniques/T1027/) |

<h4 id="DetectionRulesWiki-MalwareDetectionfromDefender-EntityMappings">Entity Mappings</h4>

- **Host:** HostName -> CompromisedEntity

---

<h3 id="DetectionRulesWiki-SuspiciousLoginActivityDetection">Suspicious Login Activity Detection</h3>

| Field | Value |
|-------|-------|
| **Status** | ENABLED |
| **Severity** | High |
| **Source** | **[View Source](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FSuspicious%20Login%20Activity%20Detection.yaml)** |

<h4 id="DetectionRulesWiki-SuspiciousLoginActivityDetection-Description">Description</h4>
Detects suspicious login activities based on failed login attempts and unusual locations

<h4 id="DetectionRulesWiki-SuspiciousLoginActivityDetection-RuleDetails">Rule Details</h4>

| Property | Value |
|----------|-------|
| **Rule Type** | Scheduled Analytics Rule |
| **Query Period** | PT1H |
| **Query Frequency** | PT1H |
| **Trigger Operator** | GreaterThan |

<h4 id="DetectionRulesWiki-SuspiciousLoginActivityDetection-MITREMapping">MITRE ATT&CK Mapping</h4>

| Category | Value |
|----------|-------|
| **Tactics** | CredentialAccess, InitialAccess |
| **Techniques** | [T1110](https://attack.mitre.org/techniques/T1110/), [T1078](https://attack.mitre.org/techniques/T1078/) |

<h4 id="DetectionRulesWiki-SuspiciousLoginActivityDetection-EntityMappings">Entity Mappings</h4>

- **Account:** FullName -> UserPrincipalName
- **IP:** Address -> IPAddress

---

<h3 id="DetectionRulesWiki-AdvancedMultistageAttackDetectionv3">Advanced Multistage Attack Detection v3</h3>

| Field | Value |
|-------|-------|
| **Status** | ENABLED |
| **Severity** | _Dynamic (ML-based)_ |
| **Source** | **[View Source](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FAdvanced%20Multistage%20Attack%20Detection%20v3.yaml)** |

<h4 id="DetectionRulesWiki-AdvancedMultistageAttackDetectionv3-Description">Description</h4>
Detects advanced multistage attacks using ML-based correlation

<h4 id="DetectionRulesWiki-AdvancedMultistageAttackDetectionv3-RuleDetails">Rule Details</h4>

| Property | Value |
|----------|-------|
| **Rule Type** | Fusion Analytics Rule (Machine Learning) |
| **Technology** | Advanced correlation and machine learning |
| **Processing** | Multi-signal attack detection |

<h4 id="DetectionRulesWiki-AdvancedMultistageAttackDetectionv3-MITREMapping">MITRE ATT&CK Mapping</h4>

| Category | Value |
|----------|-------|
| **Tactics** | _ML-based correlation_ |
| **Techniques** | _ML-based correlation identifies techniques dynamically_ |

<h4 id="DetectionRulesWiki-AdvancedMultistageAttackDetectionv3-EntityMappings">Entity Mappings</h4>

- _Entity mappings are dynamically determined by the ML correlation engine_

---

<h3 id="DetectionRulesWiki-MicrosoftDefenderforOffice365">Microsoft Defender for Office 365</h3>

| Field | Value |
|-------|-------|
| **Status** | ENABLED |
| **Severity** | _Inherited from source_ |
| **Source** | **[View Source](https://github.com/Khadinxc/SentinelxTerraform-DaC/blob/main/DetectionsYAML%2FAnalytics%20Rules%2FMicrosoft%20Defender%20for%20Office%20365.yaml)** |

<h4 id="DetectionRulesWiki-MicrosoftDefenderforOffice365-Description">Description</h4>
Creates incidents for alerts from Microsoft Defender for Office 365

<h4 id="DetectionRulesWiki-MicrosoftDefenderforOffice365-RuleDetails">Rule Details</h4>

| Property | Value |
|----------|-------|
| **Rule Type** | Microsoft Security Product Integration |
| **Data Source** | Microsoft Security Products |
| **Processing** | Automatic incident creation from product alerts |
| **Product Filter** | Office 365 Advanced Threat Protection |

<h4 id="DetectionRulesWiki-MicrosoftDefenderforOffice365-MITREMapping">MITRE ATT&CK Mapping</h4>

| Category | Value |
|----------|-------|
| **Tactics** | _Determined by underlying alerts_ |
| **Techniques** | _Determined by underlying Microsoft security product alerts_ |

<h4 id="DetectionRulesWiki-MicrosoftDefenderforOffice365-EntityMappings">Entity Mappings</h4>

- _Entity mappings are inherited from the underlying Microsoft security product alerts_

---

## Additional Resources

### Repository Information
- **Repository:** [github.com/Khadinxc/Sentinel-CICD-Detections](https://github.com/Khadinxc/SentinelxTerraform-DaC)
- **Branch:** main
- **Last Updated:** 2025-08-04 20:59:04 UTC
- **Environment:** development

### MITRE ATT&CK Framework
- **Official Website:** [attack.mitre.org](https://attack.mitre.org/)
- **Tactics Documentation:** [MITRE ATT&CK Tactics](https://attack.mitre.org/tactics/enterprise/)
- **Techniques Documentation:** [MITRE ATT&CK Techniques](https://attack.mitre.org/techniques/enterprise/)

### Microsoft Sentinel
- **Analytics Rules:** [Microsoft Documentation](https://docs.microsoft.com/en-us/azure/sentinel/detect-threats-built-in)
- **KQL Reference:** [Kusto Query Language](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/)
- **Community Rules:** [Azure Sentinel GitHub](https://github.com/Azure/Azure-Sentinel)

---

**This wiki was automatically generated from the detection manifest at** $ManifestPath 
**Generation time: 2025-08-04 20:59:04 UTC**
