/**
 * Abstract class for approval check functionality
 * 
 * @author	Tobias Mangerich 
 * @since	2013-06-03
 * @version	1.0
 * 
 *    History:
 * v1.0	TM	03.06.2013	Initial version (history unknown)
 */

// Change without effect
public abstract class AbstractApprovalCheck 
{
	private static String DEFAULT_APPROVAL_SUBJECT = ' - ';
	private static String DEFAULT_APPROVAL_TEXT = ' - ';
	protected ApprovalCheckResult approvalResult;
	protected ApprovalClarificationCheck__c specificCheck;
	
	public AbstractApprovalCheck()
	{
		approvalResult = new ApprovalCheckResult();
		approvalResult.ApprovalReasonSubject = DEFAULT_APPROVAL_SUBJECT;
		approvalResult.ApprovalDescription = DEFAULT_APPROVAL_TEXT;
		approvalResult.ApprovalNeededForSubject = false;
	}

	public void setCustomSetting(String customSettingName) {
		specificCheck = ApprovalClarificationCheck__c.getValues(customSettingName);
		approvalResult.ApprovalReasonSubject = specificCheck.Subject__c;
	}
	
}