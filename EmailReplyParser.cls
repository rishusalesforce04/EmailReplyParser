/* This class is used to parse the reply of the emails */
public with sharing class EmailReplyParser {
	
	public class EmailReplyParserException extends Exception{}
    
    private final static String CRF = '\r\n';
    private final static String NEW_LINE = '\n';
    
    /* These are the patterns we are using to parse the reply */ 
    private final static Pattern MULTI_QUOTE_HDR_REGEX = Pattern.compile('(?!On.*On\\s.+?wrote:)(On\\s(.+?)wrote:)');
    private final static Pattern SIG_REGEX = Pattern.compile('(\u2014|--|__|-\\w)|(^Sent from my (\\w+\\s*){1,3})');
	private final static Pattern QUOTED_REGEX = Pattern.compile('(>+)');
    private final static Pattern QUOTE_HDR_REGEX = Pattern.compile('^:etorw.*nO');
    
    public final String text;
    private boolean foundVisible = false;
    private List<Fragment> fragments = new List<Fragment>();
    private Fragment fragment;
    
    public EmailMessage(String text) {
    	if(String.isNotBlank(text)){
    		this.text = text.replace(CRF,'\n');
    	}else{
    		throw new EmailReplyParserException('Argument cannot be blank');
    	}
	}
	/* This method is use to initiate the parsing process */
	public static EmailMessage read(String content) {
	    EmailMessage message = new EmailMessage(content);
	    message.read();
	    return message;
	}
	
	/* This method is use to get the main reply text */
	public static String parseReply(String content) {
	    EmailMessage message = read(content);
	    return message.getReply();
	}
	
	public String getReply() {
	  	String finalReply='';
	    List<String> lines = new List<String>();
	    /* we are reversing the different fragements and consider only the hidden = true ones */
	    for( Integer i=fragments.size(); i>0; i-- ){
	    	Fragment fragmentObj = fragments.get(i-1);
	    	if( !fragmentObj.isHidden() ){
	    		finalReply = finalReply + fragmentObj.content;
	    	}
		}
		System.debug('finalReply..'+finalReply);
		return replyFramgment;
    }
	
	public void read() {
		System.debug('In Read..'+text);
	    String workingText = text;
	    Matcher multiQuote = Pattern.compile('(?m)(?s)'+MULTI_QUOTE_HDR_REGEX.pattern())
                                .matcher(workingText);
        if (multiQuote.find()) {
		      String newQuoteHeader = multiQuote.group().replace(NEW_LINE, '');
		      workingText = Pattern.compile('(?s)'+MULTI_QUOTE_HDR_REGEX.pattern()).matcher(workingText)
		      	.replaceAll(newQuoteHeader);
		}
		
		List<String> splittedList = workingText.split('\n');
		List<String> reverseList = new List<String>();
		for( Integer i = splittedList.size(); i>0; i-- ){
			String splittedStr = splittedList.get(i-1);
			reverseList.add(splittedStr);
		}
		for(String line : reverseList){
			scanLine(line);
		}
	    finishFragment();
	}
	private void scanLine(String line) {
		line = line.removeEnd(NEW_LINE).removeStart(NEW_LINE);
		if (SIG_REGEX.matcher(line).lookingAt()) {
	      	line = line.removeStart(NEW_LINE);
	    }
	    boolean isQuoted = QUOTED_REGEX.matcher(line).lookingAt();
	    if (fragment != null && String.isBlank(line.trim())) {
		    if (SIG_REGEX.matcher(fragment.lines.get(fragment.lines.size() - 1)).lookingAt()) {
		        fragment.setSignature(true);
		        finishFragment();
		    }
	    }
	    if (fragment != null &&
	      ((fragment.isQuoted() == isQuoted) ||
	        (fragment.isQuoted() && (quoteHeader(line) || String.isBlank(line))))) {
	      fragment.lines.add(line);
	    }else {
	      finishFragment();
	      fragment = new Fragment(isQuoted, line);
	    }
    }
    private boolean quoteHeader(String line) {
	    String reversed = line.reverse();
	    return QUOTE_HDR_REGEX.matcher(reversed).lookingAt();
	}
	private void finishFragment() {
	    if (fragment != null) {
	      fragment.finish();
	      if (!foundVisible) {
	        if (fragment.isQuoted() ||
	          fragment.isSignature() ||
	          String.isBlank(fragment.getContent().trim())) {
	          fragment.setHidden(true);
	        } else {
	          foundVisible = true;
	        }
	      }
	      fragments.add(fragment);
	    }
	    fragment = null;
    }
	public List<Fragment> getFragments(){
	    return fragments;
	}
	
	
	/* This is the inner class that store the different fragments(Parts) of the email 
		ie. signature,main reply text etc
		It also store the properties of the email
	*/
	class Fragment {

	    private boolean signature = false;
	    private boolean hidden = false;
	    private boolean quoted;
	    private String content;
	    private List<String> lines = new List<String>();

	    public Fragment(boolean quoted, String firstLine) {
	      this.quoted = quoted;
	      this.lines.add(firstLine);
	    }

	    public String getContent() {
	      return content;
	    }

	    public boolean isSignature() {
	      return signature;
	    }

	    public void setSignature(boolean signature) {
	      this.signature = signature;
	    }

	    public boolean isHidden() {
	      return hidden;
	    }

	    public void setHidden(boolean hidden) {
	      this.hidden = hidden;
	    }

	    public boolean isQuoted() {
	      return quoted;
	    }
	    
	    public void finish() {
			List<String> reverseList = new List<String>();
			for(Integer i=lines.size(); i>0; i--){
				String line = lines.get(i-1);
				reverseList.add(line);
			}
			content = String.join(reverseList, '\n');
			content = content.removeEnd(' ').removeStart(' '); // remove extra spaces from begining and end
	    }
  	} 
}