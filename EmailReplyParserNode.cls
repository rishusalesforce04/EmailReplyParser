public with sharing class EmailReplyParserNode {
    
    class FragmentDTO {
	  	public List<String> lines = new List<String>(); 
	    public Boolean isHidden = false;
	    public Boolean isSignature = false;
	    public Boolean isQuoted = false;
	}
	
	class Fragment {
		
		public Boolean isHidden = false;
	    public Boolean isSignature = false;
	    public Boolean isQuoted = false;
		public List<String> lines = new List<String>();
	    public String content;
	    
	    public Fragment(){}
		
		  public Fragment(String content, Boolean isHidden, Boolean isSignature, Boolean isQuoted) {
		    this.content = content;
		    this.isHidden = isHidden;
		    this.isSignature = isSignature;
		    this.isQuoted = isQuoted;
		  }
		
		  public String getContent() {
		    return this.content;
		  }
		
		  public Boolean isEmpty() {
		    return String.isBlank(content.replace('/\n/g', ''));
		  }
	}
	
	private final static  List<String> quoteHeadersRegex = new List<String>{'^\\s*(On(?:(?!^>*\\s*On\\b|\\bwrote(:)?)[\\s\\S]){0,1000}wrote:?)$',
    	'^(.+\\son.*at.*wrote:)$',
    	'^\\s*(From\\s?:.+\\s?(\\[|<).+(\\]|>))',
    	'^(20[0-9]{2})-([0-9]{2}).([0-9]{2}).([0-9]{2}):([0-9]{2})*.(.*)?\\n?(.*)>:$',
    	'^([0-9]{2}).([0-9]{2}).(20[0-9]{2})(.*)(([0-9]{2}).([0-9]{2}))(.*)\\\"( *)<(.*)>( *):$'};
    
    private final static List<Pattern> signatureRegex = new List<Pattern>{Pattern.compile('^\\s*-{2,4}$'),
    	 Pattern.compile('^\\s*_{2,4}$'),
    	 Pattern.compile('^—'),
    	 Pattern.compile('/^—\\w/'),
    	 Pattern.compile('/^-- $/'),
    	 Pattern.compile('/^-- \\s*.+$/'),
    	 Pattern.compile('/^Sent from (?:\\s*.+)$/'),
    	 Pattern.compile('/^\\+{2,4}$/'),
    	 Pattern.compile('/^\\={2,4}$/')};
   
   private final static Pattern QUOTED_REGEX = Pattern.compile('/(>+)$/');
   
   private List<Fragment> fragments = new List<Fragment>();
   
   
   public String stringReverse(String text){
		return text.reverse();
   }
   
   public String stringRTrim(String text, String mask) {
    for (Integer i = text.length() - 1; i >= 0; i--) {
      if (mask.charAt(0) != text.charAt(i)) {
        text = text.substring(0, i + 1);
        break;
      }
    }
    return text;
  }

  public String stringLTrim(String text) {
    return text.replace('/^\\s+/','');
  }
  
  public void parse(String text) {
  	System.debug('Text..'+text);
    text = text.replace('/\r\n/g', '\n');
    System.debug('Text 1..'+text);
	for(String quoteHeaderRegex : quoteHeadersRegex){
		Matcher multiQuote = Pattern.compile(quoteHeaderRegex).matcher(text);
        if (multiQuote.find()) {
        	  System.debug('is MultiQuote..');
		      String newQuoteHeader = multiQuote.group().replace('/\n/g', '');
		      text = Pattern.compile(quoteHeaderRegex).matcher(text)
		      	.replaceAll(newQuoteHeader);
		}	
	}
	System.debug('Text 2..'+text);
	
    Fragment fragment = null;
    
    for(String line : stringReverse(text).split('\n')){
    	line = stringRTrim(line, '\n');
    	System.debug('line..'+line);
    	if (!this.isSignature(line)) {
	        line = this.stringLTrim(line);
	    }
	    if (fragment != null) {
	        String last = fragment.lines[fragment.lines.size() - 1];
	        if (isSignature(last)) {
	          System.debug('This is Signature..'+last);
	          fragment.isSignature = true;
	          addFragment(fragment);
	          fragment = null;
	        } else if (String.isBlank(line) && isQuoteHeader(last)) {
	          System.debug('This is Quoted..'+last);
	          fragment.isQuoted = true;
	          this.addFragment(fragment);
	          fragment = null;
	        }
	    }
	    Boolean isQuoted = this.isQuote(line);
	    if (fragment == null || !this.isFragmentLine(fragment, line, isQuoted)) {
	        if (fragment != null) {
	          this.addFragment(fragment);
	        }
	        fragment = new Fragment();
	        fragment.isQuoted = isQuoted;
	      }
	      fragment.lines.add(line);
	 }
	 System.debug('fragment..'+fragment);
    if (fragment != null) {
      this.addFragment(fragment);
    }
    
    createEmail(this.fragments);
    
  }
  
  public void createEmail(List<Fragment> fragmentDTOs) {
    List<Fragment> fragments = new List<Fragment>();
    List<Fragment> fragmentDTOsReverse = new List<Fragment>();
    for(Integer j=fragmentDTOs.size();j>0;j--){
    	Fragment fragmentObj = fragmentDTOs.get(j-1);
    	fragmentDTOsReverse.add(fragmentObj);
	}
	for(Fragment fragment : fragmentDTOsReverse){
    	fragments.add(new Fragment(
	        this.stringReverse(String.join(fragment.lines, '\n')).replace('/^\\n/g', ''),
	        fragment.isHidden,
	        fragment.isSignature,
	        fragment.isQuoted
	      ));
	}
	System.debug('fragments..'+fragments);
  }

  public Boolean isQuoteHeader(String line) {
    Boolean  hasHeader = false;
    for(String regex : quoteHeadersRegex){
		Matcher multiQuote = Pattern.compile(regex).matcher(stringReverse(line));
        if(multiQuote.find()) {
			hasHeader = true;
		}	
	}
    return hasHeader;
  }

  public Boolean isSignature(String line) {
  	Boolean hasSignature = false;
    String text = stringReverse(line);
	for(Pattern regex : signatureRegex){
        if(regex.matcher(text).lookingAt()) {
			hasSignature = true;
			break;
		}	
	}
	return hasSignature;
  }

  public Boolean isQuote(String line) {
    return EmailReplyParserNode.QUOTED_REGEX.matcher(line).lookingAt();
  }

  public Boolean isEmpty(Fragment fragment) {
    return String.isBlank(String.join(fragment.lines, ''));
  }

  public Boolean isFragmentLine(Fragment fragment, String line, Boolean isQuoted) {
    return fragment.isQuoted == isQuoted ||
      (fragment.isQuoted && (this.isQuoteHeader(line) || line == ''));
  }

  public void addFragment(Fragment fragment) {
    if (fragment.isQuoted || fragment.isSignature || this.isEmpty(fragment)) {
      fragment.isHidden = true;
    }
    this.fragments.add(fragment);
  }
	
}