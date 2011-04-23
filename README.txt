Github Note: Development is on the 'development' branch.

----

WWW::Rietveld::API

Inteface to the Rietveld, the google hosted code review system.

Rietveld does not have an API, so data is scraped from the site.  Scraping is grody, but Web::Scraper makes it intersting by creating a scraping DSL that uses XPath and CSS selectors.

Goal: a simple interface to pull the review messages from an issue, and to parse them for "looks good to me" aka "LGTM".  

LGTM is the internal google shorthand for marking the code-review as complete and passing.  (Yes, this is ridiculous to not have this stored in a pre-parsed format.)  Auth is another hoop, requiring google two step login, that's a lot like OAuth, but not really.

The standard tool for interfacing with Rietveld is "upload.py", which is a big pile of gobblegook.  But that's because it has to do a lot -- parsing, auth, form filling, uploading patches, svn/git/ and other VCS integration, an http agent that looks like RPC, and who knows what else.  Since it's python (by Guido himself) the structure isn't documented.

See Also:

 * Google App Auth:
   http://code.google.com/apis/accounts/docs/AuthForInstalledApps.html

 * Rietveld: 
   http://code.google.com/appengine/articles/rietveld.html

    The main appengine instance is public.  Private instances are available
hosted by google labs as an add-on for google managed domains.  This provides a nice integration as everyone in your domain automatically has access to the review system.

 * Gerrit: 
   http://code.google.com/p/gerrit/ 

    Like a next-gen Rietveld for git repositories.  It has a real UI with upand down votes, ties into continuous integration, maintains a controled git repository, and a host of other neat do-dads.  Developed for use by the Google Android developers.

 * Gerrit Rietveld: 
   http://en.wikipedia.org/wiki/Gerrit_Rietveld

    Dutch Furniture Designer.
