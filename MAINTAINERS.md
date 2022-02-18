# (ULTRAEARLYACCESSDRAFT) MAINTAINERS: the guidelines and rules for Pleroma maintainers
## What's this all about
This document is mostly formalizing unspoken rules and and general "feel" of what Pleroma maintainers are supposed and not supposed to do, based on opinions and existing unwritten processes of pleroma maintainers at the time of writing.
This should be used in future to have an actual written guideline to refer to when conficts arise or when e.g. bringing new maintainer onboard.
## What are responsibilitites of a Pleroma maintainer
* Maintain Pleroma as a project in general:
  * Take action when things are falling apart.
  * Participate in discussions about features and future changes.
    * This includes things outside your scope of your understanding - i.e. frontend developer should still care for what's going on in backend, but it is understandable if you can't make heads or tails of technical things.
    * This also means start discussions about new features and future changes, either in IRC and/or in pleroma-meta subproject.
  * Within your scope of understanding, from time to time clean up old MRs and issues, i.e. close stale MRs or MRs that resolve issues that have already been implemented, close issues of things that have been resolved already, separate things into new issues, ping MR authors.
  * Volunteer to participate in administrative processes e.g. writing this document lmao
* Maintain your slice of project you have scope of understanding in.
  * Scope of understanding means "what's you're good at", i.e. PleromaFE dev/maintainer is expected to take extra care of PleromaFE, less so about other frontend projects i.e. AdminFE, and even less so for PleromaBE.
  * Fix bugs in your slice
    * It is expected for bugs to be fixed by code of people who caused them but only if it happened recently, unless it's happening in part of code someone has massive ownership of (i.e. when chunk of code was written by same person with little to no collaboration from other people, e.g. Pleroma Themes are mostly written by @HJ and it's his duty to fix bugs in there)
    * Do not leave critical bugs (bugs that people are extremely vocal about and what other maintainers are also considering to be critical) unattended for too long, even if it's beyond your understanding (i.e. aforementioned PleromaFE Themes) - try to fix them to your best ability.
  * Develop new features
    * This goes beyond just writing new code:
      * Coordinating with backend for cross-project features
      * Reviewing code of new features by other contributors in development
      * Testing new features, providing feedback both on UX and on technicalities
      
つづく...
