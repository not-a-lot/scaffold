xquery version "1.0";

(: ------------------------------------------------------------------
   Oppidoc Case Tracker application

   Creator: Stéphane Sire <s.sire@opppidoc.fr>

   Shared functions to display workflow view
   Contains the functions to generate an HTML fragment to display the entities
   which can be added inside a drawer, these are used when generating

   FIXME:
   - maybe we could move these functions directly inside lib/display.xqm ?

   January 2014 - (c) Copyright 2014 Oppidoc SARL. All Rights Reserved.
   ------------------------------------------------------------------ :)

module namespace workflow = "http://platinn.ch/coaching/workflow";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace media = "http://oppidoc.com/ns/cctracker/media" at "../../lib/media.xqm";
import module namespace activity = "http://platinn.ch/coaching/activity" at "../activities/activity.xqm";
import module namespace alert = "http://oppidoc.com/ns/cctracker/alert" at "alert.xqm";

(: ======================================================================
   Returns a list of person identifiers or the empty sequence
   for a given role in a given case and optional activi ty
   See also access:assert-semantic-role in lib/access.xqm for access control
   TBD: r:contact (or r:sme ?)
   ======================================================================
:)
declare function workflow:get-persons-for-role ( $role as xs:string, $case as element(), $activity as element()? ) as xs:string* {
  let $prefix := substring-before($role, ':')
  let $suffix := substring-after($role, ':')
  return
    if ($prefix eq 'u') then (: targets specific user :)
      fn:doc($globals:persons-uri)/Persons/Person[UserProfile/Username = $suffix]/Id/text()  (: FIXME: which realm has to be used in that case :)
    else if ($prefix eq 'g') then (: targets users belonging to a generic group :)
      let $group-ref := globals:get-normative-selector-for('Functions')/Option[@Role eq $suffix]/Id/text()
                        (: TODO: factorize as form:gen-function-ref( $suffix ) ?  :)
      return
        fn:doc($globals:persons-uri)/Persons/Person[UserProfile/Roles/Role/FunctionRef eq $group-ref]/Id/text()
    else  if ($prefix eq 'r') then
      let $func-ref := globals:get-normative-selector-for('Functions')/Option[@Role eq $suffix]/Id/text()
      return
        if ($suffix eq 'region-manager') then
          let $region-entity := $case/Information/ManagingEntity/RegionalEntityRef/text()
          return
            for $role in fn:doc($globals:persons-uri)//Role[(FunctionRef eq $func-ref) and (RegionalEntityRef eq $region-entity)]
            return $role/ancestor::Person/Id/text()
        else if ($suffix eq 'kam') then
          $case/Management/AccountManagerRef/text()
        else if ($suffix eq 'coach') then
          $activity/Assignment/ResponsibleCoachRef/text()
        else if ($suffix eq 'service-head') then
          let $service := $activity/Assignment/ServiceRef/text()
          return
            fn:doc($globals:persons-uri)/Persons/Person[UserProfile/Roles/Role[(FunctionRef eq $func-ref) and (ServiceRef eq $service)]]/Id/text()
        else if ($suffix eq 'project-officer') then
          $case/Information/ProjectOfficerRef/text()
        else
          ()
    else
      ()
};

(: ======================================================================
   Converts a list of AddresseeRef elements into a tag named element 
   containing a string with all unreferenced person's name
   ====================================================================== 
:)
declare function local:gen-addressees-for-viewing( $tag as xs:string, $addr as element()*, $lang as xs:string ) as element()? {
  if ($addr) then
    element { $tag } 
      {
      string-join(
        for $a in $addr
        return
          if (local-name($a) eq 'Addressee') then
            $a
          else if ($a eq '-1') then
            'nobody'
          else
            display:gen-person-name($a, $lang),
        ', '
        ) (: space after comma is important to garantee visualization in the browser :)
      }
  else
    ()
};

(: ======================================================================
   Transforms an alert message model into one of two screen display oriented models

   If $base is set it represents the base path to add before "alerts/#no" 
   to generate the link to open up the alert in a modal window.
   
   Note $base is optional because :
   - if set the model is generated to display a table row summary
   - if not set the model is generated to display the modal alert details window

   Note per construction To is exclusive of Addressees output (but not of CC) because e-mail
   templates with a To element (see email.xml) overwrite any other principal recipients,
   it can only be combined with CC recipients (see also alert:notify-transition in alert.xqm)
   ======================================================================
:)
declare function workflow:gen-alert-for-viewing ( $workflow as xs:string, $lang as xs:string, $item as element(), $base as xs:string? ) as element()
{
  <Alert>
    {
    if ($base) then
      attribute { 'Base' } { $base }
    else
      let $usergroups := oppidum:get-current-user-groups()
      return
        if ($item/Email) then (: e.g. SME Agreement Email, SME feedback form Email :)
          <Email>
          {
          if ($usergroups = ('coaching-assistant','coaching-manager','admin-system')) then
            $item/Email/Message
          else
            media:obfuscate($item/Email/Message),
          if ($item/Email/Attachment) then
            <Attachment>{ media:message-to-plain-text($item/Email/Attachment) }</Attachment>
          else
            ()
          }
          </Email>
        (: Workflow status changes alert :)
        else if ($usergroups = ('coaching-assistant','coaching-manager','admin-system')) then
          $item/Alert
        else
          media:obfuscate($item/Alert),
    $item/Id, 
    <Date>
      {
      (: Displays timestamp as date plus time :)
      let $value := string($item/Date)
      return
        if (string-length($value) > 10) then
          concat(display:gen-display-date(substring($value, 1, 10), $lang), ' ', substring($value, 12, 5))
        else
          display:gen-display-date($value, $lang)
      }
    </Date>,
    <ActivityStatus>
      { "display:gen-workflow-status-name" (:TODO: display:gen-workflow-status-name($workflow, $item/ActivityStatusRef,$lang):) }
    </ActivityStatus>,
    $item/Subject,
    if ($item/SenderRef) then
      <Sender>
        {
        $item/SenderRef/@Mode,
        display:gen-person-name($item/SenderRef,$lang)
        }
      </Sender>
    else
      (),
    $item/From,
    $item/To,
    local:gen-addressees-for-viewing('Addressees', $item/Addressees/AddresseeRef[not(@CC)], $lang),
    local:gen-addressees-for-viewing('CC', $item/Addressees/*[@CC], $lang)
    }
  </Alert>
};

(: ======================================================================
   Turns a row opinion into an opinion model to be transformed to HTML by workflow.xsl
   ======================================================================
:)
declare function workflow:gen-otheropinion-for-viewing ( $lang as xs:string, $item as element() ) as element()
{
  <OtherOpinion>
    <Date>{display:gen-display-date($item/Date,$lang)}</Date>
    {$item/Author}
    {$item/Comment}
  </OtherOpinion>
};

(: ======================================================================
   Turns a row logbook item into a logbook model to be transformed to HTML by workflow.xsl
   The $canDelete flag indicates wether user can delete the entry, we set it on each item
   for the case where it is generated inside an Ajax creation request
   DEPRECATED
   ======================================================================
:)
declare function workflow:gen-logbook-item-for-viewing ( $lang as xs:string, $item as element(), $canDelete as xs:boolean ) as element()
{
  <LogbookItem data-id="{$item/Id}">
    { if ($canDelete) then attribute { 'Delete' } { 'yes' } else () }
    <Date>{display:gen-display-date($item/Date,$lang)}</Date>
    <CoachRef>
      {display:gen-person-name($item/CoachRef,$lang)}
    </CoachRef>
    {$item/NbOfHours}
    {$item/ExpenseAmount}
    {$item/Comment}
  </LogbookItem>
};

(: ======================================================================
   Turns an appendix meta-data record into an annex model to be transformed to HTML by workflow.xsl
   To be called to build annexes tab content in workflow view, or to render a single row after Ajax upload
   For legacy reason the $item with meta-data is optional
   ======================================================================
:)
declare function workflow:gen-annexe-for-viewing (
  $lang as xs:string,
  $item as element()?,
  $filename as xs:string,
  $activity-no as xs:string,
  $base as xs:string?,
  $canDelete as xs:boolean ) as element()
{
  let $url := concat($activity-no, '/docs/', $filename)
  return
    <Annex>
      {
      if ($item) then
        (
        <Date SortKey="{$item/Date/text()}">
          { display:gen-display-date($item/Date, $lang) }
        </Date>,
        <ActivityStatus>
          { "display:gen-activity-status-name" (: TODO: display:gen-activity-status-name($item/ActivityStatusRef,$lang):) }
        </ActivityStatus>,
        <Sender>
          { display:gen-person-name($item/SenderRef,$lang) }
        </Sender>
        )
      else if ($base) then (: legacy appendix w/o meta-data :)
        let $date := string(xdb:created($base, $filename))
        return
          <Date SortKey="{$date}">
            { display:gen-display-date($date, $lang) }
          </Date>
      else
        ()
      }
      <File href="{$url}">
        { if ($canDelete) then attribute { 'Del' } { 1 } else () }
        { $filename }
      </File>
    </Annex>
};

(: TODO: ajouter AutoExec="name" :)
declare function workflow:gen-status-change(
  $current-status as xs:double,
  $workflow as xs:string,
  $case as element(),
  $activity as element()?,
  $id as xs:string?
  ) as element()*
{
  if (($workflow eq 'Case') and (count($case//Activity) > 0)) then
    ()
  else
    let $moves :=
      for $transition in fn:doc($globals:application-uri)//Workflow[@Id eq $workflow]//Transition[@From eq string($current-status)][@To ne '-1']
      where access:check-status-change($transition, $case, $activity)
      return $transition
    return
      if ($moves) then
        <ChangeStatus Status="{$current-status}" TargetEditor="c-alert">
          {(
          if ($id) then attribute Id { $id } else (),
          for $transition in $moves
          let $from := $current-status
          let $to := if ($transition/@To castable as xs:integer) then number($transition/@To) else ()
          let $action := if ($to) then if ($from <= $to) then 'increment' else 'decrement' else if ($transition/@To eq 'last()') then 'revert' else () 
          let $arg := if ($to) then if ($from >= $to) then $from - $to else $to - $from else ()
          return
            if ($action) then
              <Status Action="{$action}">
                { 
                if ($to) then attribute { 'Argument' } { $arg } else (),
                if ($to) then attribute { 'To' } { $to } else (),
                $transition/(@Intent | @Label | @Id) 
                }
              </Status>
            else (: TODO: throw syntax error ? :)
              ()
          )}
        </ChangeStatus>
      else
        <ChangeStatus/> (: in case there is an isolated Spawn :)
};

(: ======================================================================
   Adds extra parameters to the template URL according to application.xml
   Implements <Flag> element
   Implement @Param of <Template> element
   ======================================================================
:)
declare function local:configure-template( $doc as element(), $case as element(), $activity as element()? ) as xs:string {
  let $flags :=
    for $f in $doc/Host/Flag
    let $root := string($f/parent::Host/@RootRef)
    return
      if (access:check-user-can(string($f/@Action), $root, $case, $activity)) then
        concat(string($f/@Name), '=1')
      else
        ()
  let $params := (
    if (contains($doc/Template/@Param, 'breadcrumbs')) then
      concat('case=', $case/No, if ($activity) then concat('&amp;activity=', $activity/No) else ())
    else
      ()
    )
  let $parameters := ($flags, $params)
  return
    if (count($parameters) >= 1) then
      concat('&amp;', string-join($parameters, '&amp;'))
    else
      ''
};

(: ======================================================================
   Returns a context={Document/@Context} parameter or the empty string
   The context parameter is used to share a resource controller between
   different document editors
   ======================================================================
:)
declare function local:configure-resource( $doc as element() ) as xs:string {
  if ($doc/@Context) then
    concat('&amp;context=', $doc/@Context)
  else
    ''
};

(: ======================================================================
   Asserts activity data is compatible with document to display
   ======================================================================
:)
declare function workflow:assert-rules( $assert as element(), $case as element(), $activity as element()?, $base as element()? ) as xs:boolean {
let $rules := $assert/true
    return
      if (count($rules) > 0) then
        every $expr in $rules satisfies util:eval($expr/text())
      else
        false()
};

(: ======================================================================
   Checks if there are some assertions that prevent document to display in
   accordion.
   Returns the empty sequence in case there are no assertions to check 
   or they are all successful, returns a non-void sequence otherwise
   ======================================================================
:)
declare function workflow:validate-document($documents as element(), $doc as element(), $cur-status as xs:string, $case as element(), $activity as element()? ) as xs:boolean {
  count(
    for $assert in $doc/DynamicAssert
    return
      if ($cur-status = tokenize($assert/@AtStatus, " ")) then
        (: check for availability of some documents :)
        if (count($assert/Tab) > 0 ) then
          if (string($assert/@Rule) eq 'some') then
            if (some $tab in $assert/Tab satisfies workflow:validate-document($documents, $documents/Document[string(@Tab) eq $tab], $cur-status, $case, $activity)) then
              ()
            else (: zero implied documents are displayed so this one too :)
              '0'
          else if (string($assert/@Rule) eq 'all') then
            if (every $tab in $assert/Tab satisfies workflow:validate-document($documents, $documents/Document[string(@Tab) eq $tab], $cur-status, $case, $activity)) then
              ()
            else (: not all implied documents are displayed so this one too :)
              '0'
          else (: no rule yields an error :)
            '0'
        (: check for availability of some data :)
        else if (count($assert/true) > 0) then
          let $base := util:eval($assert/@Base)
          return
            if (string($assert/@Rule) eq 'some') then
              if (some $expr in $assert/true satisfies util:eval($expr/text())) then () else '0'
            else if (string($assert/@Rule) eq 'all') then 
              if (every $expr in $assert/true satisfies util:eval($expr/text())) then () else '0'
            else (: no rule yields an error :)
              '0'
        else (: not aware of the current status, no fail :)
          ()
      else
        ()
  ) = 0
};

(: ======================================================================
   Generates view model to display Case or Activity workflow
   ======================================================================
:)
declare function workflow:gen-information( $workflow as xs:string, $case as element(), $activity as element()?, $lang as xs:string ) {
  let $target := if ($workflow eq 'Case') then $case else $activity
  let $prev-status := $target/StatusHistory/PreviousStatusRef/text()
  let $cur-status := $target/StatusHistory/CurrentStatusRef/text()
  let $status-def := globals:get-normative-selector-for(concat($workflow, 'WorkflowStatus'))/Option[Id eq $cur-status]
  let $cur := if ($status-def/@Type eq 'final') then $prev-status else $cur-status
  return
    <Accordion CurrentStatus="{$cur-status}">
      {
      let $documents := fn:doc($globals:application-uri)//Workflow[@Id eq $workflow]/Documents
      for $doc in $documents/Document[not(@Accordion) or (@Accordion eq 'no')][not(@Deprecated)]
      let $actions := 
        for $a in $doc/Action[tokenize(string(@AtStatus), " ") = $cur-status]
        where (string($a/@Type) ne 'status')
              or (: filters 'update' actions to keep only the last one :)
              not(
                 some $x in $doc/following-sibling::Document[tokenize(string(@AtStatus), " ") = $cur]/Action[@Type eq 'status'] 
                 satisfies tokenize(string($x/@AtStatus), " ") = $cur-status
                 )
        return $a
      let $suffix := if ($doc/@Blender eq 'yes') then 'blend' else 'xml'
      return
        (: selects visible documents : either testing current status or previous status if current status is a "cementary" state :)
        if (((tokenize(string($doc/@AtStatus), " ") = $cur) or ($cur-status = tokenize(string($doc/@AtFinalStatus), " "))) and (workflow:validate-document($documents, $doc, $cur-status, $case, $activity))) then
          <Document Status="current">
          {(
          $doc/@class,
          attribute { 'Id' } { string($doc/@Tab) },
          <Name loc="workflow.title.{$doc/@Tab}">{string($doc/@Tab)}</Name>,
          <Resource>{$doc/Controller/text()}.{$suffix}?goal=read{local:configure-resource($doc)}</Resource>,
          <Template>{string($doc/parent::Documents/@TemplateBaseURL)}{$doc/Template/text()}?goal=read{local:configure-template($doc, $case, $activity)}</Template>,
          if ($actions) then
            <Actions>
              {
              for $a in $actions
              return
                if ($a/@Type = ('update', 'delete')) then
                  let $verb := string($a/@Type)
                  let $control := fn:doc($globals:application-uri)/Application/Security/Documents/Document[@TabRef = string($doc/@Tab)]
                  let $rules := $control/Action[@Type eq $verb]
                  return
                    if (access:assert-access-rules($rules, $case, $activity)) then
                      if ($verb eq 'update') then
                        <Edit>
                          { $a/@Forward }
                          <Resource>{$doc/Controller/text()}.xml?goal=update</Resource>
                          <Template>{string($doc/parent::Documents/@TemplateBaseURL)}{$doc/Template/text()}?goal=update{local:configure-template($doc, $case, $activity)}</Template>
                        </Edit>
                      else (: assumes delete :)
                        <Delete/>
                    else if (request:get-parameter('roles', ())) then  (: FIXME: temporary :)
                      <Debug>{ $rules }</Debug>
                    else
                      ()
                else if ($a/@Type eq 'status') then
                  workflow:gen-status-change(number($cur-status), $workflow, $case, $activity, string($a/@Id))
                else if ($a/@Type eq 'spawn') then
                  let $control := fn:doc($globals:application-uri)/Application/Security/Documents/Document[@TabRef eq string($a/@ProxyTab)]
                  let $rules := $control/Action[@Type eq 'create']
                  return
                    if (access:assert-access-rules($rules, $case, $activity)) then
                      let $proxy := fn:doc($globals:application-uri)//Workflow[@Id eq $workflow]/Documents/Document[@Tab eq string($a/@ProxyTab)]
                      return
                        <Spawn>
                          { $a/@Id }
                          <Controller>{$proxy/Controller/text()}</Controller>
                        </Spawn>
                    else
                      ()
                else if ($a/@Type eq 'read') then (: read access limited to subset of allowed users :) 
                  let $control := fn:doc($globals:application-uri)/Application/Security/Documents/Document[@TabRef = string($doc/@Tab)]
                  let $rules := $control/Action[@Type eq 'read']
                  return
                    if (access:assert-access-rules($rules, $case, $activity)) then
                      ()
                    else 
                      <Forbidden/>
                else
                  ()
              }
            </Actions>
          else
            (),
          if ($doc/AutoExec/@AtStatus eq $cur) then $doc/AutoExec else ()
          )}
          </Document>
        else
          ()
      }
    </Accordion>
};

declare function workflow:get-transition-for( $workflow as xs:string, $from as xs:string, $to as xs:string ) {
  fn:doc($globals:application-uri)//Workflow[@Id eq $workflow]//Transition[@From eq $from][@To eq $to]
};

(: ======================================================================
   Checks if there are some assertions that prevent transition 
   Returns the empty sequence in case there are no assertions to check 
   or they are all successful, returns an error message type string otherwise
   ======================================================================
:)
declare function workflow:validate-transition( $transition as element(), $case as element(), $activity as element()? ) as xs:string* {
  for $assert in $transition/Assert
  return
    if ($assert/@Error) then
      let $base := util:eval($assert/@Base)
      let $host := if ($activity) then $activity else $case
      return
        if (access:assert-transition-partly($host, $assert, $base)) then
          ()
        else
          string($assert/@Error)
    else
      ()
};

(: ======================================================================
   Stub to call the second version below
   ======================================================================
:)
declare function workflow:apply-transition( $transition as element(), $case as element(), $activity as element()? ) as element()? {
  if ($transition/@To eq 'last()') then
    let $history := if ($activity) then $activity/StatusHistory else $case/StatusHistory
    let $previous := $history/PreviousStatusRef/text()
    return
      if (exists($previous)) then
        workflow:apply-transition-to($previous, $case, $activity)
      else
        ()
  else
    workflow:apply-transition-to(string($transition/@To), $case, $activity)
};

(: ======================================================================
   Sets new workflow status for the activity if defined or for the case otherwise
   Returns empty sequence or an oppidum error if no status history model
   NOTE that it does not check the transition is allowed, this must be done before
   ======================================================================
:)
declare function workflow:apply-transition-to( $new-status as xs:string, $case as element(), $activity as element()? ) as element()? {
  let $history := if ($activity) then $activity/StatusHistory else $case/StatusHistory
  let $previous := $history/PreviousStatusRef
  let $current := $history/CurrentStatusRef
  let $status-log := $history/Status[ValueRef = $new-status]
  return
    if ($history) then (: sanity check :)
      (
      if ($previous) then
        update value $previous with $current/text()
      else (: first lazy creation :)
        update insert <PreviousStatusRef>{$current/text()}</PreviousStatusRef> following $current,
      if ($current) then
        update value $current with $new-status
      else (: should not happen :)
        (),
      if (empty($status-log)) then
        let $log :=
          <Status>
            <Date>{current-dateTime()}</Date>
            <ValueRef>{$new-status}</ValueRef>
          </Status>
        return
          update insert $log into $history
      else
        update replace $status-log/Date with <Date>{current-dateTime()}</Date> 
      )
    else
      oppidum:throw-error("WFSTATUS-NO-HISTORY", ())
};

(: ======================================================================
   Helper to generate the To attribute value for the requested transition
   Pre-condition: from and argument (if present) coded as numbers
   ====================================================================== 
:)
declare function local:decode-status-to( $action as xs:string, $from as xs:string, $argument as xs:string? ) as xs:string? {
  if ($action eq 'increment') then 
    string(number($from) + number($argument))
  else if ($action eq 'decrement') then
    string(number($from) - number($argument))
  else if ($action eq 'revert') then
    'last()'
  else
    ()
};

(: ======================================================================
   Implements Ajax 'status' command protocol
   Checks and returns a Transition element for a given workflow type
   or throws and returns an error element
   ======================================================================
:)
declare function workflow:pre-check-transition( $m as xs:string, $type as xs:string, $case as element()?, $activity as element()? ) as element() {
  let $item := if ($type eq 'Case') then $case else $activity
  let $action := request:get-parameter('action', ())
  let $argument := request:get-parameter('argument', 'nil')
  let $from := request:get-parameter('from', "-1")
  return
    if (($m = 'POST') and $item) then
      let $cur-status := $item/StatusHistory/CurrentStatusRef/text()
      return
        if ($from ne $cur-status) then
          ajax:throw-error('WFSTATUS-ORIGIN-ERROR', ())
        else if (not($cur-status castable as xs:decimal)) then
          ajax:throw-error('WFSTATUS-SYNTAX-ERROR', ())
        else if (not($action = ('revert', 'increment', 'decrement'))) then
          ajax:throw-error('WFSTATUS-SYNTAX-ERROR', ())
        else if (($action = ()) and not($argument castable as xs:decimal)) then
          ajax:throw-error('WFSTATUS-SYNTAX-ERROR', ())
        else
          let $to := local:decode-status-to($action, $cur-status, $argument)
          let $transition := workflow:get-transition-for($type, $from, $to)
          return
            if (not($transition)) then
              ajax:throw-error('WFSTATUS-NO-TRANSITION', ())
            else if (not(access:check-status-change($transition, $case, $activity))) then
              ajax:throw-error('WFSTATUS-NOT-ALLOWED', ())
            else
              (: checks if some document is missing data :)
              let $omissions := workflow:validate-transition($transition, $case, $activity)
              return
                if (count($omissions) gt 1) then
                  let $explain :=
                    string-join(
                      for $o in $omissions
                      let $e := ajax:throw-error($o, ())
                      return $e/message/text(), '&#xa;&#xa;')
                  return
                    ajax:throw-error(string($transition/@GenericError), concat('&#xa;&#xa;',$explain))
                else if ($omissions) then
                  ajax:throw-error($omissions, ())
                else
                  (: everything okay, returns Transition element :)
                  $transition
    else
      ajax:throw-error('URI-NOT-SUPPORTED', ())
};

(: ======================================================================
   Returns a list of recipients for the given transition from to to of the case (or activity).
   Returns a sequence of AddresseeRef elements inside an Addressees element.
   The target specifies if it is a 'Case' or 'Activity' transition.
   DEPRECATED: to be replaced with workflow:gen-recipient-refs
   ======================================================================
:)
declare function workflow:gen-recipients( $from as xs:string, $to as xs:string, $target as xs:string, $case as element(), $activity as element()? ) as element()*
{
  let $recipients := fn:doc($globals:application-uri)//Workflow[@Id eq $target]/Transitions/Transition[@From eq $from][@To eq $to]/Recipients
  let $persons :=
    for $role in tokenize($recipients/text(), ' ')
    return workflow:get-persons-for-role($role, $case, $activity)
  return
    if (count($persons) > 0) then
      <Addressees T="{$target}" From="{$from}" To="{$to}" D="{$recipients}">
        {
        for $p in distinct-values($persons)
        return <AddresseeRef>{$p}</AddresseeRef>
        }
      </Addressees>
    else
      <Addressees T="{$target}" From="{$from}" To="{$to}" D="{$recipients}"/>
};

(: ======================================================================
   Returns a list of person references or the empty sequence
   TODO: remove useless workflow parameter (!)
   ====================================================================== 
:)
declare function workflow:gen-recipient-refs( $rule as xs:string?, $workflow as xs:string?, $case as element(), $activity as element()? ) as xs:string*
{
  let $persons :=
    for $role in tokenize($rule, ' ')
    return workflow:get-persons-for-role($role, $case, $activity)
  return 
    distinct-values($persons)
};

(: ======================================================================
   Implements automatic e-mail notifications found on the transition
   For each automatic e-mail specification found generates, sends and saves it

   Actually there are two parallels automatic e-mail definition mechanisms :
   - @Mail="direct" set on the Transition element causes notification 
     to be sent directly instead of being reviewed by end-user client-side first
   - Email elements inside the Transition element are always sent directly

   This should be called after a successful transition with the success response
   so that it can inject <done/> into the response to short-circuit the e-mail
   dialog in the 'status' command client-side in case of direct mail (1st case)
   Always returns the initial success message or the augmented version

   Note that it should be called from a full pipeline so that notification success 
   or error messages are copied to the flash and communicated to the user.

   See config/application.xml
   ======================================================================
:)
declare function workflow:apply-notification(
  $workflow as xs:string,
  $success as element(),
  $transition as element(),
  $case as element(),
  $activity as element()?) as element()
{
  (
  (: 1. Implements Mail element protocol :)
  (: TODO: implement <Condition avoid="$case/Alerts/Alert[@Reason eq 'sme-fallback-notification']"/> :)
  for $mail in $transition/Email
  return alert:notify-transition($transition, $workflow, $case, $activity, $mail/@Template, $mail/Recipients),
  (: 2. Implements @Mail="direct" protocol :)
  if ($transition/@Mail eq 'direct') then (
    (: short-circuit e-mail window, see also 'status' js command :)
    alert:notify-transition($transition, $workflow, $case, $activity, $transition/@Template, $transition/Recipients),
    <success>
      <done/>
      { $success/* }
    </success>
    )[last()]
  else
    $success
  )[last()]
};

(: ======================================================================
   Generates model data to show a given type of the workflow bar
   Status may be a step or a state
   ======================================================================
:)
declare function workflow:gen-workflow-steps( $workflow as xs:string, $item as element(), $lang as xs:string ) {
  let $current-status := $item/StatusHistory/CurrentStatusRef
  let $workflow-def := globals:get-normative-selector-for(concat($workflow, 'WorkflowStatus'))
  return
    <Workflow>
      {(
      $workflow-def/@W,
      $workflow-def/@Offset,
      $workflow-def/@Name,
      for $s in $workflow-def/Option[not(@Deprecated)]
      let $ref := $s/Id/text()
      return
        if ($s/@Type eq 'final') then
          if ($ref = $current-status) then
            <Step Display="state" Status="current" StartDate="{display:gen-display-date($item/StatusHistory/Status[ValueRef = $ref]/Date, $lang)}" Num="{$ref}"/>
          else
            <Step Display="state" StartDate="{display:gen-display-date($item/StatusHistory/Status[ValueRef = $ref]/Date, $lang)}" Num="{$ref}"/>
        else (: step :)
          if ($ref = $current-status) then
            <Step Display='step' Status="current" StartDate="{display:gen-display-date($item/StatusHistory/Status[ValueRef = $ref]/Date, $lang)}" Num="{$ref}"/>
          else
            <Step Display='step' StartDate="{display:gen-display-date($item/StatusHistory/Status[ValueRef = $ref]/Date, $lang)}" Num="{$ref}">
              { if ($s/@Type eq 'final') then attribute { 'Display'} { 'state' } else () }
            </Step>
      )}
    </Workflow>
};

(: ======================================================================
   Generates the list of alerts associated to a workflow
   If the list can be completed dynamically (Ajax protocol) then the live 
   parameter must define its unique if.
   ======================================================================
:)
declare function workflow:gen-alerts-list ( $workflow as xs:string, $live as xs:string?, $item as element(), $prefixUrl as xs:string, $lang as xs:string ) as element()*
{
  <AlertsList Workflow="{$workflow}">
  {(
    if ($live) then attribute { 'Id' } { $live } else (),
    for $a in $item/Alerts/Alert
    order by number($a/Id) descending
    return workflow:gen-alert-for-viewing($workflow, $lang, $a, concat($prefixUrl, $item/No))
  )}
  </AlertsList>
};

(: ======================================================================
   Debug utility to generate an optional attribute Source with a link 
   to exist REST url of case XML model in dev mode only.
   Simple cases/YYYY/MM sharding.
   ====================================================================== 
:)
declare function workflow:gen-source ( $mode as xs:string, $case as element() ) as attribute()? {
  if ($mode eq 'dev') then
    attribute { 'Source' } { 
      let $call := $case/CreationDate/text()
      let $year := substring($call, 1, 4)
      let $month := substring($call, 6, 2)
      return concat('/exist/rest/db/sites/', $globals:app-name, '/cases/', $year,'/', $month, '/', $case/No,'/case.xml')
    }
  else
    ()
};

(: ======================================================================
   Utiliy to generate the Case and Workflow activity main title
   ======================================================================
:)
declare function workflow:gen-title ( $case as element() ) as xs:string {
  if (string-length($case/Information/Title/text()) > 80) then
    replace(substring($case/Information/Title/text(), 1, 80), "\w+...$", '...')
  else
    $case/Information/Title/text()
};

declare function workflow:gen-new-activity-tab ( $case as element(), $activity as element()?, $prefixUrl as xs:string ) as element() {
  <Tab Id="new-activity">
    <Name loc="workflow.tab.new.activity">Add</Name>
    <Heading class="case">
      <Title loc="workflow.title.new.activity">Add</Title>
    </Heading>
    {
    if (access:check-user-can('create', 'Assignment', $case)) then
      let $proxy := fn:doc($globals:application-uri)//Workflow[@Id eq 'Case']/Documents/Document[@Tab eq 'coaching-assignment']
      return
        (
        <Legend>To create a new coaching activity click on the button below. The coaching activity will start in the coaching assignment status where you will have to fill a form to assign a coach to the activity.</Legend>,
        <Legend>Because the selection of the coach should depend on the results of the needs analysis it is strongly advised to check that the needs analysis is complete first.</Legend>,
        <Spawn>
          <Controller>{$prefixUrl}{$proxy/Controller/text()}</Controller>
        </Spawn>
        )
    else
      let $cur-status := $case/StatusHistory/CurrentStatusRef/text()
      return
        if ($cur-status = ('1', '2')) then
          <Legend>This panel will show a button to create new coaching activities once the case workflow reaches the needs analysis status.</Legend>
        else
          <Legend>The functionality to create new coaching activities from the needs analysis is only available to the KAM in charge of the Case.</Legend>
    }
  </Tab>
};

declare function workflow:gen-activities-tab ( $case as element(), $activity as element()?, $lang as xs:string ) as element() {
  <Tab Id="activities" Counter="Activity">
    <Name loc="workflow.tab.activities">List coaching activities</Name>
    <Heading class="case">
      <Title loc="workflow.title.activities">List of activities</Title>
    </Heading>
    <Activities>
      { 
      let $activities := activity:gen-activities-for-case($case, $lang)
      let $cur-status := $case/StatusHistory/CurrentStatusRef/text()
      return
        (
        if ($activity/No) then
          attribute { 'Current' } { $activity/No/text() }
        else
          (),
        if (empty($activities)) then
          if ($cur-status < "3") then  (: NOTE: string order as long as less than 9 states :)
            <Legend class="c-empty">This panel will show the list of coaching activities once the case workflow reaches the needs analysis status.</Legend>
          else
            <Legend class="c-empty">There is currently no on-going coaching activity for this case.</Legend>
        else
          $activities
        (:if (access:check-user-can('create', 'Assignment', $case)) then
                          <Add TargetModal="activity">
                            <Template>../templates/coaching-assignment?goal=create&amp;n={$case-no}</Template>
                            <Controller>{$case-no}/assignment</Controller>
                            <Legend>Click on the button above to add a new Coaching activity and to assign a responsible Coach. Once you validate it the responsible Coach will receive an email asking him/her to prepare a coaching plan. <b>Before creating a Coaching activity you SHOULD complete the needs analysis document in the Case tab</b>, in particular to select the Business innovation challenges that will be used to configure the coaching activity.</Legend>                    
                          </Add>
                        else
                          ():)
        )
      }
    </Activities>
  </Tab>
};
