global class AccountCustomerProfileHelper {

    global static String NOT_MANUAL_CUSTOMER_PROFILE_CHANGE = 'NOT_MANUAL_CUSTOMER_PROFILE_CHANGE';

    public static void DecidedCustomerProfileManualChange(Map<Id, Account> newAccount, Map<Id, Account> oldAccount){
        List<Id> accountIds = new List<Id>();
        for(Account customer : newAccount.values()) {
            if (customer.Type == 'Account') {
                accountIds.add(customer.Id);
            }
        }

        Set<Id> accIdsWithCustomerProfile = new Set<Id>();
        if (accountIds.size() > 0) {
            for (Customer_Profile__c cp : [SELECT Id, Customer__c FROM Customer_Profile__c WHERE Customer__c IN :accountIds]) {
                accIdsWithCustomerProfile.add(cp.Customer__c);
            }
        }

        for(Account account : newAccount.values()) {
            if (account.Type == 'Account') {
                if (RequestState.isOn(NOT_MANUAL_CUSTOMER_PROFILE_CHANGE) && account.Manual_Customer_Profile__c == true) {
                    account.Customer_Profile__c = oldAccount.get(account.Id).Customer_Profile__c;
                }
                else if (RequestState.isOff(NOT_MANUAL_CUSTOMER_PROFILE_CHANGE)) {
                    //null Customer Profile field when no Customer Profile record exists for account
                    if (!accIdsWithCustomerProfile.contains(account.Id)) {
                        account.Customer_Profile__c = null;
                        //if CP record exists and Customer_Profile__c field was changed manually, set checkbox
                    } else if (newAccount.get(account.Id).Customer_Profile__c != oldAccount.get(account.Id).Customer_Profile__c) {
                        account.Manual_Customer_Profile__c = true;
                    }
                }
            }
        }
    }

    public static void ManualCustomerProfileTrigger(Map<Id, Account> newAccount){
        for(Account account : newAccount.values()) {
            if (account.Type == 'Account') {
                if (newAccount.get(account.Id).Manual_Customer_Profile__c == false) {
                    RequestState.setOff(NOT_MANUAL_CUSTOMER_PROFILE_CHANGE);
                    System.debug('AccountCustomerProfileHelperxxxxx: ' + RequestState.setOff(NOT_MANUAL_CUSTOMER_PROFILE_CHANGE));

                }
            }
        }
    }
}