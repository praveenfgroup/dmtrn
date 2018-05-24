/**
 * Helper class for Account
 * Used by:
 *  AccountTriggerHandler
 *  LeadHelper
 *
 * @author Jakub Mozucha
 * @since 2016-08-18
 */

public class AccountHelper {

    /* SBUs before October 2016     
    private static String FINE = 'Fine';
    private static String LABEL = 'Label';
    private static String MAGAZINE  = 'Magazine Publishing & Advertising';
    private static String MERCHANTS = 'Merchants, Home & Office';
    private static String NEWSPAPER = 'Newspaper Publishing';
    private static String UNKNOWN = 'unknown';
    */

    //New SBUs as of October 2016
    private static String SPECIALTY = 'Specialty Papers ENA';
    //DM-686 askorvaga 7.3.2017 Fine -> Fine and Specialty Papers APAC
    private static String FINE = 'Fine and Specialty Papers APAC';
    private static String NNR = 'News & Retail';
    private static String MMO = 'Magazines, Merchants & Office';
    private static String UNKNOWN = 'unknown';

    /**
    * enforceAccountRules
    *
    * @author   Olegs Denisovs
    * @since    2013-12-30
    * @version  2.0
    *
    * History:
    * v1.0  OD  02.01.2012  Initial version
    * v1.1  OD  30.12.2013  History unknown
    * v2.0  JM  07.03.2017  refactored to be used in AccountTriggerHandler
    */
    public static void enforceAccountRules(List<Account> newAccs, Map<Id, Account> newAccsMap) {
        // validate and set record types
        ID accountRT = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Account SellIT').getRecordTypeID();
        ID regularRT = Schema.SObjectType.Account.getRecordTypeInfosByName().get('SellIt').getRecordTypeID();
        ID localForecastCustomerRecordType = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Local Forecast Customer').getRecordTypeID();

        for (Account acc : newAccs) {

            if (acc.Type == 'Local Forecast Customer')
                acc.RecordTypeId = localForecastCustomerRecordType;
            else if (acc.SAP_Customer_Number__c != null && acc.SAP_Customer_Number__c != '') {
                if (acc.Type == 'Account' || acc.Type == 'Prospect Customer') {
                    acc.RecordTypeId = accountRT;
                    acc.Type = 'Account';
                }
                else {
                    acc.RecordTypeId = regularRT;
                }
            }
        }

        //    // set SVS subsegment
        //    Set<ID> agentIds = new Set<ID>();
        //    for ( Account acc : Trigger.new ) if ( acc.Agent__c <> null ) agentIds.add( acc.Agent__c );
        //    Map<ID, Account> agentMap = new Map<ID, Account>( [select Id, Agent_Region__c from Account where Id in :agentIds] );
        //    // update agents if any in current batch
        //    for ( Account acc :Trigger.new ) if ( acc.Id <> null ) agentMap.put( acc.Id, acc );
        //
        //    for ( Account acc : Trigger.new ) {
        //        // update SVS sub-segment
        //        if ( acc.Agent__c <> null ) {
        //            Account a = agentMap.get( acc.Agent__c );
        //            acc.Seven_Seas_Subsegment__c = ( a == null ) ? null : a.Agent_Region__c;
        //        }
        //        else if ( acc.Is_Agent__c ) acc.Seven_Seas_Subsegment__c = acc.Agent_Region__c;
        //        else acc.Seven_Seas_Subsegment__c = 'SVS Direct';
        //    }

        // agent IDs for SVS subsegment
        Set<ID> agentIds = new Set<ID>();
        // set new SVS subsegment
        Map<String, String> country2Region = new Map<String, String>();
        for (Seven_Seas_Country_Code_Mapping__c m : [select Name, Region__c from Seven_Seas_Country_Code_Mapping__c]) {
            country2Region.put(m.Name, m.Region__c);
        }
        Map<ID, Sales_Org__c> id2So = new Map<ID, Sales_Org__c>([select Id, Sales_Organization_SAP_Code__c, Sales_District__c, Sales_Org_SAP_Code__c from Sales_Org__c]);
        for (Account acc : newAccs) {
            Sales_Org__c so = id2So.get(acc.Sales_Org__c);
            if (so <> null && (so.Sales_Org_SAP_Code__c == 'SVS2' || so.Sales_Org_SAP_Code__c == 'SVSD')) {
                acc.Seven_Seas_Subsegment__c = acc.SAP_Country_Code__c == null ? null : country2Region.get(acc.SAP_Country_Code__c);
                if (acc.Seven_Seas_Subsegment__c == null) acc.Seven_Seas_Subsegment__c = '-unknown-';
                agentIds.add(acc.Agent__c);
            }
        }

        // sync all sales org related fields      TODO - this should be removed !!!
        //    Map<ID, Sales_Org__c> mapOfSalesOrgs = new Map<ID, Sales_Org__c>( [select Id, Sales_Organization_SAP_Code__c, Sales_District__c, Sales_Org_SAP_Code__c from Sales_Org__c] );
        for (Account acc : newAccs) {
            Sales_Org__c so = id2So.get(acc.Sales_Org__c);
            if (so <> null) {
                acc.Sales_Organization__c = so.Sales_Org_SAP_Code__c;
                acc.SAP_ID_SALES_ORG__c = so.Sales_Org_SAP_Code__c == null || acc.SAP_Customer_Number__c == null ? null : so.Sales_Org_SAP_Code__c + acc.SAP_Customer_Number__c;
                //            acc.Sales_Organization_SAP_Code__c = so.Sales_Organization_SAP_Code__c;
                //            acc.Sales_District__c = so.Sales_District__c;
            }
        }

        // if SVS then get agent SVS subsegment. If in scope of trigger replace with record from trigger
        Map<ID, Account> agents = new Map<ID, Account>([
            SELECT Id, Seven_Seas_Subsegment__c, SAP_Customer_Number__c FROM Account WHERE Id IN :agentIds
        ]);
        if(newAccsMap != null) {
            for (Account a : agents.values()) {
                if (newAccsMap.KeySet().contains(a.Id)) agents.put(a.Id, newAccsMap.get(a.Id));
            }
        }

        // Strategic Business Unit field based on Customer Type and Sales Org
        for (Account acc : newAccs) {
            String ct = '|' + acc.Customer_Type__c + '|';
            String so = '|' + acc.Sales_Organization__c + '|';
            Account agent = agents.get(acc.Agent__c);
            /* Marco Venanzoni, 07-11-2014, when Customer Record Type equals 'Prospect Customer' SBU fill logic is not applyed */
            if (acc.Type != 'Prospect Customer') { // if() added
                acc.Strategic_Business_Unit__c = AccountHelper.getStrategicBusinessUnit(ct, so, acc.Is_Agent__c, agent, acc.Seven_Seas_Subsegment__c);
            }
        }
    }

    /**
     * Method to compute Strategic Business Unit value.
     * Used mainly by LeadHelper (without Agent logic)
     */
    public static String getStrategicBusinessUnit(
        String customerType,
        String salesOrganization,
        Boolean isAgent) {

        if (String.isBlank(customerType)) customerType = '||';
        if (String.isBlank(salesOrganization)) salesOrganization = '||';

        if (!isAgent) {
            //DM-821 first APAC is determined
            if ('|AU01|JP01|HK01|SG01|CND1|KR01|'.contains(salesOrganization)) return FINE;
            else if ('|702|703|704|705|706|708|'.contains(customerType)) return SPECIALTY;
            else if (salesOrganization == '|US02|') return MMO;
            else if ('|201|701|707|204|202|226|715|'.contains(customerType)) return MMO;
            else if ('|203|207|229|231|232|'.contains(customerType))return MMO;
            else if ('|227|228|208|230|'.contains(customerType)) return NNR;
            else return UNKNOWN;
        }

        return UNKNOWN; //May only happen if agent and not SVS, i.e.: practically never!
    }

    /**
     * Method to compute Strategic Business Unit value.
     * Used mainly by EnforceAccountRules (including Agent logic)
     */
    public static String getStrategicBusinessUnit(
        String customerType,
        String salesOrganization,
        Boolean isAgent,
        Account agent,
        String AccSevenSeasSubsegment) {

        if (String.isBlank(customerType)) customerType = '||';
        if (String.isBlank(salesOrganization)) salesOrganization = '||';
        if (String.isBlank(AccSevenSeasSubsegment)) AccSevenSeasSubsegment = '||';

        if ('|SVS2|SVSD|'.contains(salesOrganization)) {
            if (agent == null && isAgent == false) return NNR;
            else if (agent == null) return AccountHelper.SVSSubsegmentToSBU(AccSevenSeasSubsegment);
            else if (agent.SAP_Customer_Number__c == '0000093408') return NNR;
            else return AccountHelper.SVSSubsegmentToSBU(agent.Seven_Seas_Subsegment__c);
        }
        else return getStrategicBusinessUnit(customerType, salesOrganization, isAgent);
    }

    /**
     * Method to compute Strategic Business Unit value based on Seven Seas Subsegment value
     */
    private static String SVSSubsegmentToSBU(String sb) {
        if (sb == 'SVS Caucasia and Central Asia') return NNR;
        else if (sb == 'SVS Eastern Latin America') return MMO;
        else if (sb == 'SVS Europe') return NNR;
        else if (sb == 'SVS India') return NNR;
        else if (sb == 'SVS Middle East') return MMO;
        else if (sb == 'SVS North Africa') return MMO;
        else if (sb == 'SVS Northern Latin America') return MMO;
        else if (sb == 'SVS South Africa') return MMO;
        // not mapped - as Traders have no agent then they will always go NEWS. UPDATED to keep old logic valid as agent logic changed
        else if (sb == 'SVS Traders') return NNR;
        else if (sb == 'SVS Western Latin America') return MMO;
        return UNKNOWN;
    }

    /* 2017-01-12 Jakub Mozucha, method updates Customer_Profile field on Account Plans after Account update */
    public static void updateCustomerProfileOnCustomerPlans(List<Account> newAccs, Map<Id, Account> oldAccs) {
        List<Account> accs = new List<Account>();
        List<Customer_Plan__c> plans = new List<Customer_Plan__c>();
        for (Account acc : newAccs) {
            //add account only if customer profile field was changed
            if (oldAccs.get(acc.Id) != null && acc.Customer_Profile__c != oldAccs.get(acc.Id).Customer_Profile__c) {
                accs.add(acc);
            }
        }
        if (accs.size() != 0) {
            plans = [
                SELECT Id, Customer__c, Customer_Profile__c, Archived__c
                FROM Customer_Plan__c
                WHERE Customer__c IN :accs
                AND Archived__c = false
            ];
        }
        if (plans != null && plans.size() != 0) {
            CustomerPlan_TriggerHelper.fillCustomerProfile(plans, accs);
            update plans;
        }
    }

    /* 2017-01-13 Jakub Mozucha, method updates Inactive__c field on customer, when IsActive__c field is changed */
    public static void updateInactiveField(List<Account> newAccs, Map<Id, Account> oldAccs) {
        for (Account acc : newAccs) {
            if (oldAccs == null || (oldAccs.get(acc.Id) != null && acc.IsActive__c != oldAccs.get(acc.Id).IsActive__c)) {
                if (acc.IsActive__c) {
                    acc.Inactive__c = null;
                }
                else {
                    acc.Inactive__c = 'X';
                }
            }
        }
    }

    // DM-701 askorvaga 2017-03-23
    public static void deleteRelatedSalesTargets(Map<Id, Account> toBeDeletedAccounts) {

        Set<Id> accountIds = toBeDeletedAccounts.keySet();

        List<Sales_Target__c> salesTargets = [Select Id From Sales_Target__c where Customer__c in :accountIds];

        delete salesTargets; 

    }

}