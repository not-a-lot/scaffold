/* ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright (C) 2012 S. Sire
 *
 * This file contains files from the AXEL-FORMS extension to the Adaptable XML Editing Library (AXEL)
 * Version @VERSION@
 *
 * AXEL-FORMS is licensed by Oppidoc SARL 
 *
 * Web site : http://www.oppidoc.fr, https://bitbucket.org/ssire/axel-forms
 * 
 * Contributors(s) : S. Sire
 * 
 * ***** END LICENSE BLOCK ***** */
 /* AXEL Command (part of AXEL-FORMS)
 *
 * author      : Stéphane Sire
 * contact     : s.sire@oppidoc.fr
 * license     : LGPL v2.1
 * last change : 2015-05-15
 *
 * Scripts to interface the AXEL library with a micro-format syntax
 * This allows to use XTiger XML templates without writing Javascript
 *
 * Prerequisites: jQuery + AXEL (https://github.com/ssire/axel)
 *
 * Copyright (c) 2012 Oppidoc SARL, <contact@oppidoc.fr>
 */

/*****************************************************************************\
|                                                                             |
|  AXEL Command                                                               |
|                                                                             |
|  manages commands bound to an HTML page with  a microformat syntax           |
|  the data-target attribute of a command identifies a target editor          |
|  that contains the result of a template transformation                      |
      exposed as $axel.command                                                |
|                                                                             |
|*****************************************************************************|
|                                                                             |
|  Command support:                                                           |
|    register( name, construtor )                                             |
|             register a new command constructor                              |
|                                                                             |
|  Generic methods:                                                           |
|    getEditor( id )                                                          |
|             returns an editor object associated with a div containing       |
|             the result of a template transformation. The editor object      |
|             has a high level API to interact with AXEL.                     |
|                                                                             |
\*****************************************************************************/
// TODO
// - factorize mandatory attributes checking (add an array of mandatory to check when calling register ?)
// - rendre id obligatoire sur Editor
// - si pas de data-target, prendre le nom du 1er Editor disponible (? legacy avec data-role ?)

(function ($axel) {

  var sindex = 0, cindex = 0;
  var registry = {}; // Command class registry to instantiates commands
  var editors = {};
  var commands = {};

  var  _Command = {

      // FIXME: replace with $axel.defaults ?
      defaults : {},

      configure : function (key, value) {
        this.defaults[key] = value;
      },

      // DEPRECATED : replace with $axel.error instead
      logError : function (msg, opt) {
        $axel.error(msg, opt);
      },

      // Adds a new command factory
      register : function (name, factory, params) {
        var record = { factory : factory };
        if (params) {
          $axel.extend(record, params);
        }
        registry[name] = record;
      },

      getEditor : function (key) {
        return editors[key];
      },
      
      getCommand : function (name, key) {
        var _name = name,
            _key = key,
            c = commands[key],
            found = c ? c[name] : undefined;
        return found || { execute : function () { alert('Command ' + _name  + ' not found on ' + _key) }  };
      }
  };

  function _addEditor (key, editor) {
    xtiger.cross.log('debug',"adding editor " + key);
    editors[key] = editor; // stores editor for getEditor
  }

  // Creates 'transform' commands, note that implicit ones
  // (i.e. w/o an associated data-command='transform') will immediately generate an editor
  function _createEditor (node, doc) {
    var key = $(node).attr('id') || ('untitled' + (sindex++)),
        res = new registry['transform'].factory(key, node, doc);
    xtiger.cross.log('debug',"registering editor " + key);
    editors[key] = res; // stores editor for getEditor
    return res;
  }

  // Creates a new command from a DOM node
  // FIXME: data-command='template' exception (exclusion or handle it properly)
  function _createCommand (node, type, doc) {
    var key =  $(node).attr('data-target') || ('untitled' + (cindex++)),
        id = $(node).attr('id'),
        record = registry[type],
        done;
    // xtiger.cross.log('debug', 'create command "' + type + '"' + ' on target "' + key + '"');
    if (record) {
      if (record.check) {
        if ($axel.command.getEditor(key)) { // checks editor existence
            if (node.disabled) { // activates trigger
              node.disabled = false;
            }
            done = new registry[type].factory(key, node, doc); // command constructor should register to trigger event
        } else {
          node.disabled = true; // unactivates trigger
          $axel.error('Missing or invalid data-target attribute in ' + type + ' command ("' + key + '")');
        }
      } else {
        done = new registry[type].factory(key, node, doc); // command constructor should register to trigger event
      }
      if (done && id) { // stores command for getCommand
        if (! commands[id]) {
          commands[id] = {};
        }
        commands[id][type] = done;
      }
    } else {
      $axel.error('Attempt to create an unkown command "' + type + '"');
    }
    // xtiger.cross.log('debug', 'created command "' + type + '"' + ' on target "' + key + '"');
  }

  // when sliceStart/sliceEnd is defined installs on a slice
  // works with snapshot since execution may change document tree structure
  function _installCommands ( doc, sliceStart, sliceEnd ) {
    var i, cur, sel,
        start = sliceStart || doc,
        stop = sliceEnd || sliceStart,
        buffer1 = [],
        buffer2 = [],
        accu = [];

    // xtiger.cross.log('debug', 'installing commands ' + (sliceStart ? 'slice mode' :  'document mode'));
    // make a snapshot of nodes with data-template command over a slice or over document body
    sel = sliceStart ? '[data-template]' : '* [data-template]'; // body to avoid head section
    cur = start;
    do {
      $(sel, cur).each( function(index, n) { buffer1.push(n); } );
      cur = sliceStart ? cur.nextSibling : undefined;
    } while (cur && (cur !== sliceEnd) && (stop != sliceStart));

    // make a snapshot of nodes with data-command over a slice or over document body
    sel= '[data-command]';
    cur = start;
    do {
      $(sel, cur).each( 
        function(index, n) {
          if ($(n).attr('data-command') !== 'transform') {
            buffer2.push(n);
          } else if (! $(n).attr('data-template')) {
            buffer1.push(n);
          }
        });
      cur = sliceStart ? cur.nextSibling : undefined;
    } while (cur && (cur !== sliceEnd) && (stop != sliceStart));

    // create editors - FIXME: merge with other commands (?)
    if (_Command.defaults.bundlesPath) {
      for (i = 0; i < buffer1.length; i++) {
        accu.push(_createEditor(buffer1[i], doc));
      }
    } else if (buffer1.length > 0) {
      $axel.error('Cannot start editing because AXEL bundles path is unspecified');
    }

    // create other commands
    for (i = 0; i < buffer2.length; i++) {
      buffer1 = $(buffer2[i]).attr('data-command').split(' ');
      for (cur = 0; cur < buffer1.length; cur++) {
        _createCommand(buffer2[i], buffer1[cur], doc);
      }
    }

    return accu;
  }

  // exports module
  $axel.command = _Command;
  $axel.command.install = _installCommands;
  $axel.command.addEditor = _addEditor;

  // AXEL extension that rewrites url taking into account special notations :
  // ~/ to inject current location path
  // ^/ to inject data-axel-base base URL (requires a node parameter to look updwards for data-axel-basee)
  // $^ to be replaced with the latest location path segment (could be extended with $^^ for second before the end, etc.)
  // Note that it removes any hash tag or search parameters
  $axel.resolveUrl = function resolveUrl ( url, node ) {
    var res = url, tmp;
    if (url && (url.length > 2)) {
      if (url.charAt(0) === '~' && url.charAt(1) === '/') {
        if ((window.location.href.charAt(window.location.href.length - 1)) !== '/') {
          res = window.location.href.split('#')[0] + '/' + url.substr(2);
        } else {
          res = url.substr(2);
        }
      } else if (url.charAt(0) === '^' && url.charAt(1) === '/') {
        res = ($(node).closest('*[data-axel-base]').attr('data-axel-base') || '/') + url.substr(2);
      }
      if (res.indexOf('$^') !== -1) {
        tmp = window.location.href.split('#')[0].match(/([^\/]+)\/?$/); // FIXME: handle URLs with parameters  
        if (tmp) {
          res = res.replace('$^', tmp[1]);
        }
      }
    }
    return res;
  };

  // document ready handler to install commands (self-transformed documents only)
  jQuery(function() { 
    var script = $('script[data-bundles-path]'),
        path = script.attr('data-bundles-path'),
        when = script.attr('data-when'),
        lang;
    if (path) { // saves 'data-bundles-path' for self-transformable templates
      _Command.configure('bundlesPath', path);
      // FIXME: load sequence ordering issue (?)
      $axel.filter.applyTo({ 'optional' : ['input', 'choice'], 'event' : 'input' });
    }
    // browser language detection
    if (navigator.browserLanguage) {
      lang = navigator.browserLanguage;
    } else {
      lang = navigator.language;
    }
    if (lang) {
      lang = lang.substr(0,2);
      if (xtiger.defaults.locales[lang]) {
        $axel.setLocale(lang);
        xtiger.cross.log('debug','set lang to ' + lang);
      }
    }
    // command(s) installation
    if ('deferred' !== when) {
      _installCommands(document);
    }
  });
}($axel));
 /* ***** BEGIN LICENSE BLOCK *****
  *
  * Copyright (C) 2012 S. Sire
  *
  * This file contains files from the AXEL-FORMS extension to the Adaptable XML Editing Library (AXEL)
  * Version @VERSION@
  *
  * AXEL-FORMS is licensed by Oppidoc SARL
  *
  * Web site : http://www.oppidoc.fr, https://bitbucket.org/ssire/axel-forms
  *
  * Contributors(s) : S. Sire
  *
  * ***** END LICENSE BLOCK ***** */

/*****************************************************************************\
|                                                                             |
|  AXEL Binding                                                               |
|                                                                             |
|  manages bindings life cycle (registration)                                 |
|  exposed as $axel.binding                                                   |
|                                                                             |
|*****************************************************************************|
|  Prerequisites: jQuery, AXEL                                                |
|                                                                             |
|  Global functions:                                                          |
|    $axel.binding.register                                                   |
|        registers a binding object                                           |
|                                                                             |
|  TODO:                                                                      |
|  - lazy klass creation ?                                                    |
|                                                                             |
\*****************************************************************************/
(function ($axel) {

  var registry = {};

  /////////////////////////////
  // Default binding Mixin  //
  ////////////////////////////
  var _bindingK = {

    getDocument : function () {
      return this._doc;
    },

    getParam : function (name) {
        return this._param[name] || this._defaults[name];
    },

    getVariable : function () {
        return this._variable;
    }
  };

  /////////////////////////////
  // Optional binding Mixin  //
  ////////////////////////////
  var _bindingErrorK = {

    // Extracts optional errScope and forges errSel selector to locate error display
    _installError : function ( host ) {
      // FIXME: we could check first a binding specific data-:binding-error-scope
      this.errScope = host.attr('data-error-scope') || undefined;
      this.errSel = '[data-' + this.getName() + '-error="' + this.getVariable() + '"]';
    },

    // Either hide or show error message depending on valid
    // anchor is the DOM node to used as the starting point in case of a scoped error
    toggleError : function (valid, anchor) {
      var error, scope, doc = this.getDocument();
      if (! this.errScope) { // search error in full document
        error = $('body ' + this.errSel, doc);
      } else if (anchor) { // search error within scope
        scope = $(anchor, doc).closest(this.errScope);
        error = $(this.errSel, scope.get(0));
      }
      if (error) {
        if (valid) {
          error.hide();
        } else {
          error.show();
        }
      }
      return valid;
    }
  };

  function _createBingingKlass ( name, options, klassdefs ) {
    var klass = new Function();
    klass.prototype = (function (name) {
      var _NAME = name;
      return {
       getName : function () { return _NAME; }
      };
    }(name));

    $axel.extend(klass.prototype, _bindingK); // inherits default binding methods

    // inherits optoinal mixin modules
    if (options && options.error) {
      $axel.extend(klass.prototype, _bindingErrorK);
    }

    // copy life cycle methods
    klass.prototype.onInstall = klassdefs.onInstall;

    // copy other methods
    $axel.extend(klass.prototype, klassdefs.methods, false, true);
    return klass;
  }
  
  // Implements required property of fields
  // Validates fields which registered a validating binding (with an isValid function)
  // Sets af-required and af-invalid pre-defined classes if missing or invalid data
  // Computes and inserts a summary error message in the errid container if necessary 
  // You can deactivate the summary if errif is undefined (e.g. for pre-validating)
  // TODO: internationalize summary error messages
  function _validate (fields, errid, doc, cssrule) {
    var res, feedback, evt,
        labsel = cssrule || '.af-label', // selector rule to extract label
        err = [], // required error
        valid = [];  // validation error
      fields.apply(
      function (field) {
        // we consider failure to meet required implies field is valid
        var rcheck = (field.getParam('required') === 'true'),
            vcheck = field.isValid,
            rsuccess = (field.getParam('required') !== 'true') || field.isModified(), 
            vsuccess = (!rsuccess) || (!field.isValid || field.isValid()), 
            f = $(field.getHandle()),
            l = f.parents().children(labsel).first(), // FIXME: too wide ?
            label, i;
        if (rsuccess && rcheck) {
          f.removeClass('af-required');
          l.removeClass('af-required');
        }
        if (vsuccess && vcheck) {
          f.removeClass('af-invalid');
          l.removeClass('af-invalid');
        }
        if ((rcheck || vcheck) && (!rsuccess || !vsuccess)) {
          // FIXME: contents().filter(function () { return (this.nodeType === 3) } )
          // because contents(':not(span)') may throw exception
          label = l.contents(':not(span)').text(); // filters inner span (useful to skip hints)
          // .parent().children(labsel).text();
          i = label.lastIndexOf(':');
          if (i != -1) {
            label = label.substr(0, i);
          }
          label = $.trim(label);
          if (!rsuccess && rcheck) {
            f.addClass('af-required');
            l.addClass('af-required');
            err.push(label);
          } else if (vcheck) {
            f.addClass('af-invalid');
            l.addClass('af-invalid');
            valid.push(label);
          }
        }
      }
    );
    if (errid) {
      feedback = $('#' + errid, doc).html('');
      if (err.length > 0) {
        feedback.append(
          '<p>' + xtiger.util.getLocaleString('errFormRequired', { 'fields' : err.join(', ') }) + '</p>'
        );
      }
      if (valid.length > 0) {
        feedback.append(
          '<p>' + xtiger.util.getLocaleString('errFormInvalid', { 'fields' : valid.join(', ') }) + '</p>'
        );
      }
      res = (err.length === 0) && (valid.length === 0);
      if (!res) {
        feedback.addClass('af-validation-failed');
        evt = $.Event('axel-validate-error', { required: err.length, invalid: valid.length });
        feedback.triggerHandler(evt);
      } else {
        feedback.removeClass('af-validation-failed');
      }
    }
    return res;
  }
  
  // Extends a primitive editor instance with an isValid function 
  // that executes a validator function (a validator function is a function 
  // returning true or false - usually associated with a binding)
  // Validator functions are chained if one is already present
  function _addValidator (editor, validator) {
    if (editor) {
      if (typeof editor.isValid === "function") {
        editor.isValid.extend(validator);
      } else {
        editor.isValid = function ( func ) { 
            var _chain = [ func ];
            var _valid = function () {
              var i, res = true;
              for (var i = 0; i < _chain.length; i++) {
                res = res && _chain[i](this); // "this" should be the AXEL primitive editor
              }
              return res;
            }
            _valid.extend = function ( func ) {
              _chain.push(func);
            }
            return _valid;
          } (validator);
      }
    } else {
      xtiger.cross.log('error', 'attempt to set a validator function on an undefined editor');
    }
  }

  // Creates and register a new binding class applying optional mixins
  // and declaring parameters
  function _registerBinding ( name, options, parameters, binding ) {
    var defaults = {}, 
        k = _createBingingKlass(name, options, binding);
    $axel.extend(defaults, parameters); // copy default parameters
    registry[name] = {
      name : name,
      options : options,
      defaults : defaults,
      klass : k // FIXME: lazy ?
    };
  }

  // instantiate one binding on a JQuery wrapped host node in a document
  function _installBinding (spec, host, doc ) {
    var k, binding, defaults, cur, param = {}, ok = true;
    var key = host.attr('data-variable'); // mandatory
    if (key) {
      // parses parameters and cancel creation if required parameters are missing
      defaults = spec.defaults;
      for (k in defaults) {
        if (defaults.hasOwnProperty(k)) {
          cur = host.attr('data-' + k);
          if (cur) {
            param[k] = cur;
          } else if (defaults[k] === $axel.binding.REQUIRED) {
            xtiger.cross.log('error', 'Missing attribute "data-' + k + '" to install "' + spec.name + '" binding');
            ok = false;
            break;
          }
        }
      }
      if (ok) {
        binding = new spec.klass();
        binding._doc = doc;
        binding._variable = key;
        binding._defaults = defaults;
        binding._param = param;
        // mixin specific initializations
        if (spec.options && spec.options.error) {
          binding._installError(host);
        }
        // call life cycle method
        binding.onInstall(host); 
        // xtiger.cross.log('debug', 'installed binding "' + spec.name + '"');
        return binding;
      }
    } else {
      xtiger.cross.log('error', 'Missing attribute "data-variable" to install "' + spec.name + '" binding');
    }
  }

  // when sliceStart/sliceEnd is defined installs on a slice
  function _installBindings ( doc, sliceStart, sliceEnd ) {
    var cur = sliceStart || doc,
        stop = sliceEnd || sliceStart,
        sel = sliceStart ? '[data-binding]' : 'body [data-binding]'; // body to avoid head section
    // xtiger.cross.log('debug', 'installing bindings ' + (sliceStart ? 'slice mode' :  'document mode'));
    do {
      $(sel, cur).each(
        function(index, n) {
          var i, el = $(n),
              names = el.attr('data-binding').split(' ');
          for (i = 0; i < names.length; i++) {
            if (registry[names[i]]) {
              // xtiger.cross.log('debug', 'installing binding "' + names[i] + '"');
              _installBinding(registry[names[i]], el, doc);
            } else {
              xtiger.cross.log('error', 'unregistered binding "' + names[i] + '"');
            }
          }
        }
      );
      cur = sliceStart ? cur.nextSibling : undefined;
    } while (cur && (cur !== sliceEnd) && (stop != sliceStart));
  }

 $axel.binding = $axel.binding || {};
 
 $axel.binding.list = function () {
   var key, accu = [];
   for (key in registry) { accu.push(key); }
   return accu;
 };

 // exports functions
 $axel.binding.register = _registerBinding;
 $axel.binding.install = _installBindings;
 $axel.binding.validate = _validate; 
 $axel.binding.setValidation = _addValidator;
 $axel.binding.REQUIRED = 1; // constant to declare required parameters
}($axel));

/*****************************************************************************\
|                                                                             |
|  AXEL Oppidum interface module                                              |
|                                                                             |
|  Implementation of Oppidum Ajax responses                                   |
|  Functions to be called from commands to intepret server's response         |
|                                                                             |
|  TODO: rename to neutral $axel.reponse (response.js) to support adaptation  |
|  to more server-side back-ends                                              |
|                                                                             |
\*****************************************************************************/

(function ($axel) {

  var  _Oppidum = {

    // Converts XHR response into client-side Oppidum command
    // Currently this is just a simple object containing response as an XML document
    // or as a JSON document (json) and retaining the original XHR object
    // TODO: in JSON only status makes difference between success / error (no root)
    getCommand : function ( xhr ) {
      var doc, parser, type,
          cmd = { xhr: xhr };
      if (xhr.responseXML) {
        cmd.doc = xhr.responseXML;
      } else {
        type = xhr.getResponseHeader('Content-Type');
        if ($axel.oppidum.checkJSON(type)) { // tries to parse as JSON
          try {
            cmd.json = JSON.parse(xhr.responseText);
          } catch (e) {
          }
        } else { // tries to parse as XML
          parser = xtiger.cross.makeDOMParser();
          try {
            cmd.doc = parser.parseFromString(xhr.responseText, "text/xml");
          } catch (e) { // nope
          }
        }
      }
      return cmd;
    },

    // Implements redirection with Location header
    // Returns true if no redirection or false otherwise
    // Currently redirection is supposed to supersede any other feedback
    filterRedirection : function ( cmd ) {
      var loc = cmd.xhr && cmd.xhr.getResponseHeader('Location'),
          res = true;
      if (loc) {
        window.location.href = loc;
        res = false;
      }
      return res;
    },

    // Returns the message part of an Ajax response as a string
    decodeMessage : function ( cmd ) {
      var msg;
      if (cmd.doc) {
        msg = $('success > message', cmd.doc).text();
      } else if (cmd.json) {
        msg = cmd.json.message ? cmd.json.message['#text'] : 'missing "message" element in response';
      } else {
        msg = xhr.responseText;
      }
      return msg;
    },

    // Implements the message part of an Ajax response
    handleMessage : function ( cmd ) {
      var msg = $axel.oppidum.decodeMessage(cmd);
      if (msg) {
        alert(msg); // FIXME: integrate reporting with flash ?
      }
    },

    // Implements the <forward> element of an Ajax response
    handleForward : function ( cmd ) {
      var command, target, host, ev;
      if (cmd.doc) {
        host = $('success > forward', cmd.doc);
        command = host.attr('command');
        target = host.text();
      }
      if (command && target) {
        ev = { synthetic: true, command : cmd };
        $axel.command.getCommand(command, target).execute(ev);
      }
    },

    // Tests if type string represents JSON MIME Type
    checkJSON : function ( type ) {
      var json = "application/json";
      return (typeof type === 'string') && (type.slice(0, json.length) === json);
    },

    // DEPRECATED - Returns the text message of a successful response
    unmarshalMessage : function ( xhr ) {
      var text = xhr.responseXML ? $('success > message', xhr.responseXML).text() : xhr.responseText;
      return text;
    },

    // Returns the payload content as text of a successful response with payload
    // In particular payload may contain HTML for injection (e.g. 'save' command)
    // NOTE: for JSON response you should directly use cmd.json.payload (!)
    unmarshalPayload : function ( xhr ) {
      var start = xhr.responseText.indexOf('<payload>'),
          end,
          res = xhr.responseText;
      if (-1 !== start) {
        end = xhr.responseText.indexOf('</payload>');
        if (-1 !== end) {
          res = xhr.responseText.substr(start + 9, end - start - 9) ;
        }
      }
      return res;
    },

    // Returns true if the XHR response is an Oppidum error message
    // which can be returned indifferently as xml or as json
    isResponseAnOppidumError : function (xhr ) {
      var type = xhr.getResponseHeader('Content-Type'),
          res = false;
      if (xhr.responseXML) {
        res = $('error > message', xhr.responseXML).size() > 0;
      } else if ($axel.oppidum.checkJSON(type)) {
        try {
          res = JSON.parse(xhr.responseText).message !== undefined;
        } catch (e) {
        }
      }
      return res;
    },

    getOppidumErrorMsg : function (xhr ) {
      var type = xhr.getResponseHeader('Content-Type'),
          res;
      if (xhr.responseXML) {
        res = $('error > message', xhr.responseXML).text();
      } else if ($axel.oppidum.checkJSON(type)) {
        try {
          res = JSON.parse(xhr.responseText).message['#text'];
        } catch (e) {
        }
      } else {
        res = xhr.responseText;
      }
      return res || xhr.status;
    },

    // Tries to extract more info from a server error. Returns a basic error message
    // if it fails, otherwise returns an improved message
    // Compatible with eXist 1.4.x server error format (which is returned as plain HTML - no JSON)
    getExistErrorMsg : function (xhr) {
      var text = xhr.responseText, status = xhr.status;
      var msg = 'Error ! Result code : ' + status;
      var details = "";
      var m = text.match('<title>(.*)</title>','m');
      if (m) {
        details = '\n' + m[1];
      }
      m = text.match('<h2>(.*)</h2>','m');
      if (m) {
        details = details + '\n' + m[1];
      } else if ($('div.message', xhr.responseXML).size() > 0) {
        details = details + '\n' + $('div.message', xhr.responseXML).get(0).textContent;
        if ($('div.description', xhr.responseXML).size() > 0) {
          details = details + '\n' + $('div.description', xhr.responseXML).get(0).textContent;
        }
      }
      return msg + details;
    },

    // Same parameters as the one received by the jQuery Ajax error callback
    // a) XHR object, b) status message (error,timeout, notmodified, parseerror)
    // c) optional exception sometimes returned from XHR, plus d) url
    parseError : function (xhr, status, e, url) {
      var loc, msg;
      if (status === 'timeout') {
        msg = xtiger.util.getLocaleString("errServerTimeOut");
      } else if (xhr.status === 409) { // 409 (Conflict)
        loc = xhr.getResponseHeader('Location');
        if (loc) {
          window.location.href = loc;
          msg = xtiger.util.getLocaleString("msgRedirect");
        } else {
          msg = $axel.oppidum.getOppidumErrorMsg(xhr);
        }
      } else if ($axel.oppidum.isResponseAnOppidumError(xhr)) {
        // Oppidum may generate 500 Internal error, 400, 401, 404
        msg = $axel.oppidum.getOppidumErrorMsg(xhr);
      } else if (xhr.responseText.search('Error</title>') !== -1) { // HTML generated eXist-db error (empirical)
        msg = $axel.oppidum.getExistErrorMsg(xhr);
      } else if (e && (typeof e === 'string')) {
        msg = xtiger.util.getLocaleString('errException', { e : { message : e }, status : xhr.status });
      } else if (e) {
        msg = xtiger.util.getLocaleString('errException', { e : e, status : xhr.status });
      } else if (url) {
        msg = xtiger.util.getLocaleString('errLoadDocumentStatus', { url : url, xhr: xhr });
      } else if (xhr.responseText !== '') {
        msg = xhr.responseText;
      } else {
        msg = xtiger.util.getLocaleString('errLoadDocumentStatus', { xhr: xhr });
      }
      return msg;
    }
  };

  // registers 'protocol.upload' message decoder
  xtiger.registry.registerFactory('protocol.upload',
    {
      getInstance : function (doc) {
        return {
          decode_success : function (xhr) {
            var loc = xhr.getResponseHeader('Location');
            if (loc) {
              window.location.href = loc;
            }
            return (-1 !== xhr.responseText.indexOf('<payload')) ? $axel.oppidum.unmarshalPayload(xhr) : $axel.oppidum.unmarshalMessage(xhr);
          },
          decode_error : function (xhr) {
            return $axel.oppidum.parseError(xhr, xhr.status);
          }
        };
      }
    }
  );

  // exports module
  $axel.oppidum = _Oppidum;
}($axel));
/**
 * AXEL-FORMS "choice" plugin
 *
 * HTML forms "select/option" element wrapper
 *
 * Synopsis :
 *  - <xt:use types="choice" param="noselect=---" values="one two three"/>
 *
 * TODO :
 *  - insert in keyboard manager focus chain
 *  - factorize code with "select" plugin or merge all into a "list" plugin
 *
 */

(function ($axel) {

  var _Editor = (function () {

   // Splits string s on every space not preceeded with a backslash "\ "
   // Returns an array
   // FIXME: move to xtiger.util
   function _split ( s ) {
     var res;
     if (s.indexOf("\\ ") === -1) {
       return s.split(' ');
     } else {
       res = s.replace(/\\ /g, "&nbsp;");
       return xtiger.util.array_map(res.split(' '),
          function (e) { return e.replace(/&nbsp;/g, " "); }
        );
     }
   }

   // items is array of the form [{ label: XXX, value : YYY }]
   function replaceOptions ( that, items ) {
     var i, o, t, handle = that.getHandle(),
         doc = that.getDocument(),
         type = that.getParam('multiple') === 'yes' ? 'checkbox' : 'radio',
         readonly = that.getParam('noedit') === 'true' ? 'disabled="true" ' : '',
         name = that.getUniqueKey(),
         full = that.getParam('appearance') === 'full';
     $('*', handle).remove(":not(.axel-choice-placeholder)"); // reset options
     if (items && (items.length > 0)) {
       for (i = 0; i < items.length; i++) {
         if (full) {
           $(handle).append('<li><label><input ' + readonly + 'type="' + type + '" value="' + items[i].value + '" name ="' + name + '"/>' + items[i].label + '</label></li>');
         } else {
           o = xtdom.createElement(doc, 'option');
           t = xtdom.createTextNode(doc, items[i].label);
           xtdom.setAttribute(o, 'value', items[i].value);
           if (that.getParam('noedit') === 'true') {
             xtdom.setAttribute(o, 'disabled', true);
           }
           o.appendChild(t);
           handle.appendChild(o);
         }
       }
       $(handle).prop('disabled', false);
     } else {
       $(handle).prop('disabled', true);
     }
   }

   // options is an array of the form [labels, values]
   function createOptions ( that, values, labels ) {
     var i, o, t, handle = that.getHandle(),
         doc = that.getDocument(),
         type = that.getParam('multiple') === 'yes' ? 'checkbox' : 'radio',
         readonly = that.getParam('noedit') === 'true' ? 'disabled="true" ' : '',
         name = that.getUniqueKey(),
         full = that.getParam('appearance') === 'full';
     if (values && (values.length > 0)) {
       for (i = 0; i < values.length; i++) {
         if (full) {
           $(handle).append('<li><label><input ' + readonly + 'type="' + type + '" value="' + values[i] + '" name ="' + name + '"/>' + labels[i] + '</label></li>');
         } else {
           o = xtdom.createElement(doc, 'option');
           t = xtdom.createTextNode(doc, labels[i]);
           xtdom.setAttribute(o, 'value', values[i]);
           if (that.getParam('noedit') === 'true') {
             xtdom.setAttribute(o, 'disabled', true);
           }
           o.appendChild(t);
           handle.appendChild(o);
         }
       }
     } else {
       $(handle).prop('disabled', true);
     }
   }

    // compute if new state is significative (i.e. leads to some non empty XML output)
   //  meaningful iff there is no default selection (i.e. there is a placeholder)
   function _calcChange (defval, model) {
     var res = true;
     if (! defval) {
       if (typeof model === "string") { // single
         res = model !== defval;
       } else { // multiple
         if (!model || ((model.length === 1) && !model[0])) {
           res = false;
         }
       }
     } else { // FIXME: assumes no multiple default values
       res = model !== defval;
     }
     return res;
   }

   return {

     ////////////////////////
     // Life cycle methods //
     ////////////////////////

     // Plugin static view: span showing current selected option
     onGenerate : function ( aContainer, aXTUse, aDocument ) {
      var viewNode;
      if (this.getParam('appearance') === 'full') {
        viewNode= xtdom.createElement (aDocument, 'ul');
      } else {
        viewNode= xtdom.createElement (aDocument, 'select');
      }
      xtdom.addClassName(viewNode,'axel-choice');
      aContainer.appendChild(viewNode);
      return viewNode;
     },

     onInit : function ( aDefaultData, anOptionAttr, aRepeater ) {
       var values = this.getParam('values');
       if (this.getParam('hasClass')) {
         xtdom.addClassName(this._handle, this.getParam('hasClass'));
       }
       if (this.getParam('multiple') === 'yes') {
         $(this._handle).attr('multiple', 'multiple');
       }
       // builds options if not cloned from a repeater
       if (! aRepeater) {
          createOptions(this, this.getParam('values'), this.getParam('i18n'));
       }
     },

     onAwake : function () {
       var  _this = this,
            defval = this.getDefaultData(),
            pl = this.getParam("placeholder"),
            handle = $(this._handle);
       if ((this.getParam('appearance') !== 'full') && (pl || (! defval))) {
         pl = pl || "";
         // inserts placeholder option (unless instantiated from a repeater and it exists)
         if (handle.find('.axel-choice-placeholder').length === 0) {
           handle.prepend('<option class="axel-choice-placeholder" selected="selected" value="">' + (pl || "") + '</option>');
         }
         // creates default selection
         if (!defval) {
           this._param.values.splice(0,0,pl);
           if (this._param.i18n !== this._param.values) { // FIXME: check its correct
             this._param.i18n.splice(0,0,pl);
           }
           if (pl) {
             handle.addClass("axel-choice-placeholder");
           }
         }
       }
       xtdom.addEventListener(this._handle, 'change',
        function (ev, data) {
          if (!(data && data.synthetic)) { // short circuit if forged event (onLoad)
            if (_this.getParam('appearance') === 'full') {
              var accu = [];
              $('input', _this.getHandle()).each(
                function(i,e) { 
                  if (e.checked) {
                    accu.push($(e).val());
                  }
                }
              );
              _this.update(accu);
            } else {
              _this.update($(xtdom.getEventTarget(ev)).val()); // with option element jQuery returns the value attribute
            }
          }
        }, true);
        this._setData(defval);
     },

     onLoad : function (aPoint, aDataSrc) {
       var value, defval, option, xval,tmp;
       if (aDataSrc.isEmpty(aPoint)) {
         this.clear(false);
       } else {
         xval = this.getParam('xvalue');
         defval = this.getDefaultData();
         if (xval) { // custom label
           value = [];
           option = aDataSrc.getVectorFor(xval, aPoint);
           while (option !== -1) {
             tmp = aDataSrc.getDataFor(option);
             if (tmp) {
               value.push(tmp);
             }
             option = aDataSrc.getVectorFor(xval, aPoint);
           }
           this._setData(value.length > 0 ? value : ""); // "string" and ["string"] are treated as equals by jQuery's val()
         } else { // comma separated list
           tmp = aDataSrc.getDataFor(aPoint);
           if (typeof tmp !== 'string') {
             tmp = '';
           }
           value = (tmp || defval).split(",");
           this._setData(value);
         }
         this.set(false);
         this.setModified(_calcChange(defval,value));
       }
     },

     onSave : function (aLogger) {
       var tag, data, i;
       if ((!this.isOptional()) || this.isSet()) {
         if (this._data && (this._data !== this.getParam('placeholder'))) {
           tag = this.getParam('xvalue');
           if (tag) {
             if (typeof this._data === "string") {
               aLogger.openTag(tag);
               aLogger.write(this._data);
               aLogger.closeTag(tag);
             } else {
               for (i=0;i<this._data.length;i++) {
                 if (this._data[i] !== "") { // avoid empty default (i.e. placeholder)
                   aLogger.openTag(tag);
                   aLogger.write(this._data[i]);
                   aLogger.closeTag(tag);
                 }
               }
             }
           } else {
             aLogger.write(this._data.toString().replace(/^,/,''));
           }
         }
       } else {
         aLogger.discardNodeIfEmpty();
       }
     },

     ////////////////////////////////
     // Overwritten plugin methods //
     ////////////////////////////////

     api : {

       // FIXME: first part is copied from Plugin original method,
       // an alternative is to use derivation and to call parent's method
       _parseFromTemplate : function (aXTNode) {
         var tmp, defval;
         this._param = {};
         xtiger.util.decodeParameters(aXTNode.getAttribute('param'), this._param);
         defval = xtdom.extractDefaultContentXT(aXTNode); // value space (not i18n space)
         tmp = aXTNode.getAttribute('option');
         this._option = tmp ? tmp.toLowerCase() : null;
         // completes the parameter set
         var values = aXTNode.getAttribute('values'),
             i18n = aXTNode.getAttribute('i18n'),
             _values = values ? _split(values) : [],
             _i18n = i18n ? _split(i18n) : undefined;
         this._param.values = _values; // FIXME: validate both are same lenght
         this._param.i18n = _i18n || _values;
         this._content = defval || "";
       },

       isFocusable : function () {
         return true;
       },

       focus : function () {
         // nop : currently Tab focusing seems to be done by the browser
       }
     },

     /////////////////////////////
     // Specific plugin methods //
     /////////////////////////////

     methods : {

       // dynamically constructs options list
       ajax : function ( config ) {
         replaceOptions(this, config.items);
         // TODO: change defaultData because the value may diverge
         // (remove it if placeholder or set it to first option otherwise)
         if (config.restore) {
           this._setData(this._data);
         } else {
           this.clear(false);
         }
       },

       // FIXME: modifier l'option si ce n'est pas la bonne actuellement ?
       _setData : function ( value, withoutSideEffect ) {
         var values;
         if (this.getParam('appearance') !== 'full') {
           if(!value && (this.getParam('placeholder'))) {
             $(this.getHandle()).addClass("axel-choice-placeholder");
           } else {
             $(this.getHandle()).removeClass("axel-choice-placeholder");
           }
         }
         this._data =  value || "";
         if (! withoutSideEffect) {
           if (this.getParam('appearance') === 'full') {
             values = typeof this._data === "string" ? [ this._data ] : this._data; // converts to array
             $('input', this.getHandle()).each(
               function(i,e) { 
                 if ($.inArray($(e).val(), values) > -1) {
                   e.checked = true;
                   xtdom.removeClassName(e.parentNode,'axel-choice-unset');
                 } else {
                   e.checked = false;
                   xtdom.addClassName(e.parentNode,'axel-choice-unset');
                 }
               }
             );
           } else {
             $(this.getHandle()).val(value);
           }
         }
       },

       dump : function () {
         return this._data;
       },

      // Updates the data model consecutively to user input
      // single: aData should be "" or any string value
      // multiple: aData should be null or [""] or any array of strings
       update : function (aData) {
         var meaningful = _calcChange(this.getDefaultData(), aData);
         this.setModified(meaningful);
         this._setData(aData, true);
         this.set(meaningful);
       },

       clear : function (doPropagate) {
         this._setData(this.getDefaultData());
         if (this.isOptional()) {
           this.unset(doPropagate);
         }
       }
     }
   };
  }());

  $axel.plugin.register(
    'choice',
    { filterable: true, optional: true },
    {
     choice : 'value'  // alternative is 'display'. FIXME : this parameter seems unused, remove
    },
    _Editor
  );
  
  $axel.filter.applyTo({'event' : ['choice']});
}($axel));
/**
 * AXEL-FORMS "choice" plugin
 *
 * HTML forms "select/option" element wrapper
 *
 * Synopsis :
 *  - <xt:use types="choice" param="noselect=---" values="one two three"/>
 *
 * TODO :
 *  - insert in keyboard manager focus chain
 */

(function ($axel) {

  var _Editor = (function () {

    // Utility to convert a hash objet into an html double-quoted style attribute declaration string
    function _style( rec ) {
      var key, tmp = [];
      for (key in rec) {
        if (rec[key]) {
          tmp.push(key + ':' + rec[key]);
        }
      }
      key = tmp.join(';');
      return key  ? ' style="' + key + '"' : '';
    }

   function _createPopup ( that, menu ) {
     var k1, k2, tmp = '',
         buff = that.getParam('choice2_width1'),
         style1 = _style({ 'width' : buff }),
         config2 = { 'left' : buff, 'width' : that.getParam('choice2_width2')},
         style2;
     if (that.getParam('choice2_position') === 'left') {
       config2['margin-left'] = '-' + (parseInt(buff) + parseInt(config2.width) + 2) + 'px';
     }
     style2 = _style(config2);
     for (k1 in menu) {
       buff = '';
       for (k2 in menu[k1]) {
         if (k2 !== '_label') {
           buff += '<li class="choice2-label" data-code="' + k2 + '">' + menu[k1][k2] + '</li>';
         }
       }
       tmp += '<li class="choice2-option"><div class="choice2-item"' + style1 + '>' + k1 + ' ' + menu[k1]._label + '</div><ul class="choice2-popup2 choice2-drop-container"' + style2 + '>' + buff + '</ul></li>';
     }
     tmp = '<ul class="choice2-popup1 choice2-drop-container"' + style1 + '>' + tmp.replace(/&/g,'&amp;') + '</ul>';
     $(that.getHandle()).append(tmp);
   }

   // Utility to select level 1 option when all level 2 options selected
   function _fixItemSelection ( item ) {
     if (0 === item.find('li.choice2-label:not(.selected)').size()) {
       item.addClass('selected');
     } else {
       item.removeClass('selected');
     }
   }

    // compute if new state is significative (i.e. leads to some non empty XML output)
   //  meaningful iff there is no default selection (i.e. there is a placeholder)
   function _calcChange (defval, model) {
     var res = true;
     if (! defval) {
       if (typeof model === "string") { // single
         res = model !== defval;
       } else { // multiple
         if (!model || ((model.length === 1) && !model[0])) {
           res = false;
         }
       }
     } else { // FIXME: assumes no multiple default values
       res = model !== defval;
     }
     return res;
   }

   return {

     ////////////////////////
     // Life cycle methods //
     ////////////////////////

     // Plugin static view: span showing current selected option
     onGenerate : function ( aContainer, aXTUse, aDocument ) {
      var viewNode,
          style = { 'width' : this.getParam('choice2_width0') };
      viewNode= xtdom.createElement (aDocument, 'div');
      xtdom.addClassName(viewNode,'axel-choice2');
      $(viewNode).html('<div class="select2-container-multi"' + _style(style) + '><ul class="select2-choices"></ul></div>');
      aContainer.appendChild(viewNode);
      return viewNode;
     },

     onInit : function ( aDefaultData, anOptionAttr, aRepeater ) {
       var values = this.getParam('values');
       if (this.getParam('hasClass')) {
         xtdom.addClassName(this._handle, this.getParam('hasClass'));
       }
       // builds options if not cloned from a repeater
       if (! aRepeater) {
          _createPopup(this, this.getParam('values'));
       }
     },

     onAwake : function () {
       var  _this = this,
            defval = this.getDefaultData(),
            pl = this.getParam("placeholder");
       if ((this.getParam('appearance') !== 'full') && (pl || (! defval))) {
         pl = pl || "";
         // inserts placeholder option
         // $(this._handle).prepend('<span class="axel-choice-placeholder">' + (pl || "") + '</span>');
         // creates default selection
         // if (!defval) {
           // this._param.values.splice(0,0,pl);
           // if (this._param.i18n !== this._param.values) { // FIXME: check its correct
           //   this._param.i18n.splice(0,0,pl);
           // }
           // if (pl) {
           //   $(this._handle).addClass("axel-choice-placeholder");
           // }
         // }
       }
      this._setData(defval);
      $(this._handle).children('div.select2-container-multi').click($.proxy(this, '_handleClickOnChoices'));
      $(this._handle).find('li.choice2-label').click($.proxy(this, '_handleClickOnLabel'));
      $(this._handle).find('div.choice2-item').click($.proxy(this, '_handleClickOnItem'));
     },

     onLoad : function (aPoint, aDataSrc) {
       var value, defval, option, xval,tmp;
       if (aDataSrc.isEmpty(aPoint)) {
         this.clear(false);
       } else {
         xval = this.getParam('xvalue');
         defval = this.getDefaultData();
         if (xval) { // custom label
           value = [];
           option = aDataSrc.getVectorFor(xval, aPoint);
           while (option !== -1) {
             tmp = aDataSrc.getDataFor(option);
             if (tmp) {
               value.push(tmp);
             }
             option = aDataSrc.getVectorFor(xval, aPoint);
           }
           this._setData(value.length > 0 ? value : "");
         } else { // comma separated list
           tmp = aDataSrc.getDataFor(aPoint);
           if (typeof tmp !== 'string') {
             tmp = '';
           }
           value = (tmp || defval).split(",");
           this._setData(value);
         }
         this.set(false);
         this.setModified(_calcChange(defval,value));
       }
     },

     onSave : function (aLogger) {
       var tag, data, i;
       if ((!this.isOptional()) || this.isSet()) {
         if (this._data && (this._data !== this.getParam('placeholder'))) {
           tag = this.getParam('xvalue');
           if (tag) {
             if (typeof this._data === "string") {
               aLogger.openTag(tag);
               aLogger.write(this._data);
               aLogger.closeTag(tag);
             } else {
               for (i=0;i<this._data.length;i++) {
                 if (this._data[i] !== "") { // avoid empty default (i.e. placeholder)
                   aLogger.openTag(tag);
                   aLogger.write(this._data[i]);
                   aLogger.closeTag(tag);
                 }
               }
             }
           } else {
             aLogger.write(this._data.toString().replace(/^,/,''));
           }
         }
       } else {
         aLogger.discardNodeIfEmpty();
       }
     },

     ////////////////////////////////
     // Overwritten plugin methods //
     ////////////////////////////////

     api : {

       // FIXME: first part is copied from Plugin original method,
       // an alternative is to use derivation and to call parent's method
       _parseFromTemplate : function (aXTNode) {
         var tmp, defval;
         this._param = {};
         xtiger.util.decodeParameters(aXTNode.getAttribute('param'), this._param);
         defval = xtdom.extractDefaultContentXT(aXTNode); // value space (not i18n space)
         tmp = aXTNode.getAttribute('option');
         this._option = tmp ? tmp.toLowerCase() : null;
         // completes parameter set
         var values = aXTNode.getAttribute('values'),
             _values = JSON.parse(values);
         this._param.values = _values;
         this._content = defval || "";
       },

       isFocusable : function () {
         return true;
       },

       focus : function () {
         // nop : currently Tab focusing seems to be done by the browser
       }
     },

     /////////////////////////////
     // Specific plugin methods //
     /////////////////////////////

     methods : {

       // Click on the list of current choices
       _handleClickOnChoices : function ( e ) {
         var t = $(e.target),
             h = $(e.target).closest('.axel-choice2'),
             n, pos, height, val;
         if (t.hasClass('select2-choices') || t.hasClass('select2-label')) { // open/close popup
           pos = t.hasClass('select2-label') ? t.closest('.select2-choices').offset() : t.offset();
           height = t.hasClass('select2-label') ? t.closest('.select2-choices').height() : t.height();
           n = h.children('ul.choice2-popup1');
           if (n.hasClass('show')) { // will be closed
             $('div.select2-container-multi ul', this._handle).css('minHeight', ''); // unlock height
           }
           n.toggleClass('show').offset( { top : pos.top + height + 1, left: pos.left });
           // var totalHeight = h.children('ul.choice2-popup1').height();
           // h.children('ul.choice2-popup1').offset( { top : pos.top - totalHeight, left: pos.left })
         } else if (t.hasClass('select2-search-choice-close')) { // remove single choice
           t = $(e.target).closest('li[data-code]').first();
           val = t.attr('data-code');
           n = h.find('ul.choice2-popup1 li.choice2-label[data-code="' + val +'"]').removeClass('selected');
           this.removeFromSelection(val, n);
           t.remove();
           e.stopPropagation();
         }
       },

       // Click on a popup level 1 option
       _handleClickOnItem :function (e) {
         var n = $(e.target),
             options = n.parent().find('li.choice2-label'),
             multiple = "yes" === this.getParam('multiple'),
             _this = this;
         if (multiple || (1 === options.size())) {
           if (n.parent().hasClass('selected')) {
             options.each(
               function (i,e) {
                 var n = $(e);
                 _this.removeFromSelection(n.attr('data-code'), false);
                 n.removeClass('selected');
               }
             );
           } else {
             if (! multiple) { // unselect the other
                this.setSelection([]);
             }
             options.each(
               function (i,e) {
                 var n = $(e);
                 _this.addToSelection(n.attr('data-code'), n.text());
                 n.addClass('selected');
               }
             );
           }
           n.parent().toggleClass('selected');
         }
       },

       // Click on a popup level 2 option
       _handleClickOnLabel : function (e) {
         var n = $(e.target);
         if (("yes" !== this.getParam('multiple')) && !n.hasClass('selected')) { // unselect the other
           this.setSelection([]);
         }
         n.toggleClass('selected');
         if (n.hasClass('selected')) { // has been selected
           this.addToSelection(n.attr('data-code'), n.text());
           _fixItemSelection(n.closest('.choice2-option'));
         } else { // has been unselected
           this.removeFromSelection(n.attr('data-code'), n);
         }
       },

       setSelection : function (values ) {
         var tmp = '',
             set = $('li.choice2-label', this._handle),
             i, label;
         // reset all
         set.filter('.selected').removeClass('selected');
         for (i = 0; i < values.length; i++) {
           if (values[i].length > 0) {
             label = set.filter('[data-code="' + values[i] + '"]').first().addClass('selected').text();
             tmp += '<li class="select2-search-choice" data-code="' + values[i] + '"><div class="select2-label">' + label.replace(/&/g,'&amp;') + '</div><a class="select2-search-choice-close" tabindex="-1" onclick="return false;" href="#"></a></li>';
           }
         }
         $('div.select2-container-multi > ul', this._handle).html(tmp);
         $('li.choice2-option', this._handle).each ( function (i, e) { _fixItemSelection($(e)); } );
       },

       addToSelection : function (value, name) {
         var sel = $('div.select2-container-multi > ul', this._handle);
         if ((sel.find('li.select2-search-choice[data-code="' + value + '"]')).size() === 0) {
           sel.append(
             '<li class="select2-search-choice" data-code="' + value + '"><div class="select2-label">' + name.replace(/&/g,'&amp;') + '</div><a class="select2-search-choice-close" tabindex="-1" onclick="return false;" href="#"></a></li>'
             );
           if ('true' === this.getParam('choice2_closeOnSelect')) {
             $('ul.choice2-popup1', this._handle).removeClass('show');
           }
           this.update($('li.select2-search-choice', this._handle).map( function(i, e) { return $(e).attr('data-code'); } ).get());
         }
       },

       removeFromSelection : function (value, checkParent) {
         var n = $('div.select2-container-multi ul', this._handle);
         if ($(this._handle).children('ul.choice2-popup1').hasClass('show')) {
           n.css('minHeight', n.height() + 'px'); // locks height to avoid "jump"
         }
         $('div.select2-container-multi li[data-code="' + value + '"]', this._handle).remove();
         this.update($('li.select2-search-choice', this._handle).map( function(i, e) { return $(e).attr('data-code'); } ).get());
         if (checkParent) {
           checkParent.closest('.choice2-option').removeClass('selected');
         }
       },

       // FIXME: modifier l'option si ce n'est pas la bonne actuellement ?
       _setData : function ( value, withoutSideEffect ) {
         var values;
         //if(!value && (this.getParam('placeholder'))) {
           // $(this.getHandle()).addClass("axel-choice-placeholder");
         // } else {
           // $(this.getHandle()).removeClass("axel-choice-placeholder");
         // }
         this._data =  value || "";
         if (! withoutSideEffect) {
           values = typeof this._data === "string" ? [ this._data ] : this._data; // converts to array
           this.setSelection(values);
         }
       },

       dump : function () {
         return this._data;
       },

      // Updates the data model consecutively to user input
      // single: aData should be "" or any string value
      // multiple: aData should be null or [""] or any array of strings
       update : function (aData) {
         var meaningful = _calcChange(this.getDefaultData(), aData);
         this.setModified(meaningful);
         this._setData(aData, true);
         this.set(meaningful);
       },

       clear : function (doPropagate) {
         this._setData(this.getDefaultData());
         if (this.isOptional()) {
           this.unset(doPropagate);
         }
       }
     }
   };
  }());

  $axel.plugin.register(
    'choice2',
    { filterable: true, optional: true },
    {
    },
    _Editor
  );

  $axel.filter.applyTo({'event' : ['choice2']});
}($axel));
/**
 * Class InputFactory
 *
 * HTML forms "input" element wrapper
 *
 * Currently handles a subset of input types (see Synopsis)
 *
 * Synopsis :
 *  - <xt:use types="input" param="type=(text|password|radio|checkbox|date)[;placeholder=string]">default value</xt:use>
 *  - placeholder parameter is only for a 'text' or 'date' input
 *
 * Limitations :
 * - you can set only one 'beforeShow' calback at a time (cf. bindings/interval.js)
 * - 'date' sub-type is only available if jQuery datepicker mdule is loaded in the SAME window as the transformed template
 * - 'date' not really inserted in AXEL tabbing (don't register to keyboard manager)
 *
 * TODO :
 *  - load empty values (undefined)
 *  - placeholder=clear
 *  - detect if HTML5 and use placeholder for 'text' input hint instead of default content
 *
 */
(function ($axel) {

  ////////////////////////////////////////////////////////////////
  // Utility functions to aggregate radio buttons / check boxes //
  ////////////////////////////////////////////////////////////////

  var _CACHE= {}; // TODO: define and subscribe to load_begin / load_end events to clear it
  var _CLOCK= {}; // Trick to generate unique names for radio button groups

  // name may be undefined in case of checkbox with unique XML tag
  var _encache = function _encache(name, value) {
    if (name) {
      if (!_CACHE[name]) {
        _CACHE[name] = {};
      }
      _CACHE[name][value] = true;
    }
  };

  // name may be undefined in case of checkbox with unique XML tag
  var _decache = function _decache (name, value) {
    var res = false;
    if (name) {
      if (_CACHE[name] && _CACHE[name][value]) {
        delete _CACHE[name][value];
        res = true;
      }
    }
    return res;
  };

  // Returns date of the day in the date_region format of the editor
  // Pre-condition: there must be a $.datepicker
  var _genTodayFor = function (editor) {
      var format = editor.getParam('date_format'); // either pre-defined constant of custom format date string
      return xtiger.util.date.convertDate(editor, $.datepicker.formatDate($.datepicker[format] || format, new Date()), 'date_format' , 'date_region');
  };

  var _getClockCount = function (name, card) {
    var tmp = parseInt(card),
        num = ((tmp === 0) || (isNaN(tmp))) ? 1 : tmp; // FIXME: could be stored once into param
    if (_CLOCK[name] === undefined) {
      _CLOCK[name] = 0;
    } else {
      _CLOCK[name] += 1;
    }
    return Math.floor(_CLOCK[name] / num);
  };

  var _formatTextBlock = function (stack, aLogger) {
    var cur;
    if (stack.length > 1) {
      aLogger.openTag('Block');
      while (cur = stack.shift()) {
        aLogger.openTag('Line');
        aLogger.write(cur);
        aLogger.closeTag('Line');
      }
      aLogger.closeTag('Block');
    } else if (1 === stack.length) {
      aLogger.openTag('Text');
      aLogger.write(stack.pop());
      aLogger.closeTag('Text');
    }
  };
  
  // returns true if node contains at least one non-empty Element children
  var _containElements = function (node) {
    var cur = node.firstChild, res = false;
    while (cur) {
      if (cur.nodeType === xtdom.ELEMENT_NODE && cur.firstChild) {
        res = true;
        break;
      }
      cur = cur.nextSibling;
    }
    return res;
  };
  
  var _normalizeEntry = function (multi, value) {
    var res;
    if (multi === 'normal') { // normalization
      res = $.trim(value).replace(/((\r\n|\n|\r)+)/gm,"$2$2").replace(/(\r\n|\n|\r)\s+(\r\n|\n|\r)/gm,"$1$2");
    } else if (multi === 'enhanced') {
      res = $.trim(value).replace(/((\r\n|\n|\r){2,})/gm,"$2$2").replace(/(\r\n|\n|\r)\s+(\r\n|\n|\r)/gm,"$1$2");
    } else {
      res = $.trim(value);
    }
    return res;
  };

  ///////////////////////////////
  // Keyboard Field Base Mixin //
  ///////////////////////////////

  var _KeyboardMixinK = {

    subscribe : function (handle) {
      var _this = this;
      var _StartEditingMixin = function(ev) {
        if (!_this.isEditing()) {
          _this.startEditing(ev);
        }
        xtdom.stopPropagation(ev);
        xtdom.preventDefault(ev);
      };
      if (this.isEditable) {
        // 'focus' event triggered either when landing from keyboard tab navigation or from 'click' event
        xtdom.addEventListener(handle, 'focus', _StartEditingMixin, true);
        xtdom.addEventListener(handle, 'mouseup', // needed on Safari to prevent unselection
          function(ev) {
            xtdom.stopPropagation(ev);
            xtdom.preventDefault(ev);
          }, true);
      }
    },

    isFocusable : function () {
      return (this.isEditable && ((!this._editor.isOptional()) || this._editor.isSet()));
    },

    // AXEL keyboard API (called from Keyboard manager instance)
    isEditing : function () {
      return this._isEditing;
    },

    // AXEL keyboard API (called from Keyboard manager instance)
    doKeyDown : function (ev) {
    },

    // AXEL keyboard API (called from Keyboard manager instance)
    doKeyUp : function (ev) {
    },

    // AXEL tab group manager API
    // Gives the focus to *this* instance. Called by the tab navigation manager.
    focus : function () {
      this._editor.getHandle().focus();
      this.startEditing();
    },

    // AXEL tab group manager API
    // Takes the focus away from *this* instance. Called by the tab navigation manager.
    unfocus : function () {
      this.stopEditing();
    },

    // Called by Keyboard manager (Esc key)
    cancelEditing : function () {
      this._editor.getHandle().value = this._legacy;
      this.stopEditing(true, false);
    },

    clear : function () {
      this._editor.getHandle().value = this.defaultData;
    },

    // Updates this model with the given data.
    // If this instance is optional and "unset", autocheck it.
    update : function (aData) {
      // 1. no change
      if (aData === this._legacy) {
        return;
      }
      // 2. normalizes text (empty text is set to _defaultData)
      if (aData.search(/\S/) === -1 || (aData === this._defaultData)) {
        this._editor.clear(true);
      } else {
        // 2. notifies data was updated
        this._editor.setModified(aData !== this.defaultData);
        this._editor.set(true);
      }
    }
  };

  /////////////////////
  // Keyboard Field  //
  /////////////////////

  // Internal class to manage an HTML input with a 'text', 'number' or 'password' type
  // Currently 'number' type is not passed to HTML but is treated as 'text' because
  // it requires extra configuration like steps some of which browser's dependent
  var _KeyboardField = function (editor, aType, aData) {
    var h = editor.getHandle(),
        t = 'number' !== aType ? aType : 'text',
        size;
    this._editor = editor;
    this.isEditable = !editor.getParam('noedit');
    this.defaultData = aData || '';
    xtdom.setAttribute(h, 'type', t);
    if (size = editor.getParam('size')) {
      xtdom.setAttribute(h, 'size', size);
    }
    h.value = this.defaultData;
    // FIXME: placeholder if HTML5 (?)
  };

  _KeyboardField.prototype = {

    awake : function () {
      var h = this._editor.getHandle();
      var _this = this;
      this.subscribe(h);
      if (this.isEditable) {
        xtdom.addEventListener(h, 'blur',
          function(ev) {
            if (_this.isEditing()) {
              _this.stopEditing(false, true);
            }
          }, true);
      }
    },

    load : function (aPoint, aDataSrc) {
      var value, fallback, multi;
      if (aPoint !== -1) {
        multi = this._editor.getParam('multilines');
        if ((multi === 'normal') || (multi === 'enhanced')) {
          if (_containElements(aPoint[0])) {
            var cur = aPoint[0].firstChild, line,
                buffer = '';
            while (cur) {
              if (cur.nodeType === xtdom.ELEMENT_NODE && cur.firstChild) {
                if ('Text' === cur.nodeName) {
                  buffer = buffer + cur.firstChild.nodeValue + '\n\n';
                } else if ('Block' === cur.nodeName) {
                  line = cur.firstChild;
                  while (line) {
                    if (line.nodeType === xtdom.ELEMENT_NODE && line.firstChild) { // assumes Line
                      buffer = buffer + line.firstChild.nodeValue + '\n';
                    }
                    line = line.nextSibling;
                  }
                  buffer = buffer + '\n';
                }
              }
              cur = cur.nextSibling;
            }
            value = buffer;
          } else { // auto-migration of legacy plain text content
            value = _normalizeEntry(multi, aDataSrc.getDataFor(aPoint));
          }
        } else {
          value = aDataSrc.getDataFor(aPoint);
        }
        fallback = this._editor.getDefaultData();
        this._editor.getHandle().value = value || fallback || '';
        this._editor.setModified(value !==  fallback);
        this._editor.set(false);
      } else {
          this._editor.clear(false);
      }
    },

    save : function (aLogger) {
      var val = $.trim(this._editor.getHandle().value),
          pending, _scanner;

      var singleLineI = function (str, found) {
        if (found.length > 0)  {
          aLogger.openTag('Text');
          aLogger.write(found);
          aLogger.closeTag('Text');
        }
      };

      var singleLineII = function (str, found) {
        var sep = str.charCodeAt(1);
        if ((sep === 10) || (sep === 13)) {
          _formatTextBlock(pending, aLogger);
          pending = [];
        }
        if (found.length > 0) {
          pending.push(found);
        }
      };

      if (val) {
        multi = this._editor.getParam('multilines');
        if (multi) {
          _scanner = new RegExp("[\n\r]{0,}(.*)", "g");
          if ('normal' === multi) {
            val.replace(_scanner, singleLineI);
          } else { // assumes enhanced
            pending = [];
            val.replace(_scanner, singleLineII);
            _formatTextBlock(pending, aLogger);
          }
        } else if ('number' === this._editor.getParam('type')) {
          aLogger.write(val.replace(',','.')); // forces decimal point representation
        } else {
          aLogger.write(val);
        }
      }
    },

    // Starts an edition process on *this* instance's device.
    startEditing : function (aEvent) {
      var h, kbd = xtiger.session(this._editor.getDocument()).load('keyboard');
      if (! this._isEditing) {
        h = this._editor.getHandle();
        this._legacy = h.value;
        this._isEditing = true;
        // registers to keyboard events
        this.kbdHandlers = kbd.register(this, h);
        kbd.grab(this, this._editor); // this._editor for Tab group manager to work
        if (this._editor.getParam('multilines')) {
          kbd.enableRC(true);
        }
        if (!this._editor.isModified()) {
          xtdom.focusAndSelect(h);
        }
      }
    },

    // Stops the ongoing edition process
    stopEditing : function (isCancel, isBlur) {
      var h, kbd, multi;
      if (this._isEditing) {
        h = this._editor.getHandle();
        kbd = xtiger.session(this._editor.getDocument()).load('keyboard');
        this._isEditing = false; // do it first to prevent any potential blur handle callback
        kbd.unregister(this, this.kbdHandlers, h);
        kbd.release(this, this._editor);
        if ('normal' === this._editor.getParam('multilines')) {
          kbd.disableRC();
        }
        if (!isCancel) {
          multi = this._editor.getParam('multilines');
          h.value = _normalizeEntry(multi, h.value);
          this._editor.update(h.value);
        }
        if ((! isBlur) && (h.blur)) {
          h.blur();
        }
      }
    }
  };

  /////////////////
  // Date Field  //
  /////////////////

  // Internal class to manage an HTML input with a 'text' or 'password' type
  var _DateField = function (editor, aType, aData) {
    xtdom.setAttribute(editor.getHandle(), 'type', 'text');
    this._editor = editor;
    this.isEditable = !editor.getParam('noedit');
    this.defaultData = aData || '';
    this.dpDone = false; // datepicker init done
  };

  _DateField.prototype = {

    // Initializes datepicker on demand because we do not want to create it from scratch
    // to avoid beeing set on shadow clone when instantiated inside a repeater
    lazyInit : function (h) {
      var tmp, _this = this;
      if ($.datepicker) {
        // trick to detect 'Esc' key since keyboard manager seem to be overriden by datepicker
        $(h).on('keydown', function(evt) {
                if (evt.keyCode === $.ui.keyCode.ESCAPE) {
                    _this.onEscape();
                }
                xtdom.stopPropagation(evt);
            });
        // turns field into a datepicker
        this.jhandle = $(h).datepicker( { 'onClose' : function () { _this.onClose(); } } );
      } else {
        alert('datepicker jQuery plugin needed for "date" input field !');
      }
      this.dpDone = true;
    },

    awake : function () {
      var h = this._editor.getHandle();
      this.subscribe(h);
      if (this.defaultData === 'today') {
        h.value = this.defaultData = $.datepicker ? _genTodayFor(this._editor) : new Date();
      } else {
        h.value = xtiger.util.date.convertDate(this._editor, this.defaultData, 'date_format' , 'date_region');
      }
      this.model = h.value;
      // size defaults (could be done once in constructor)
      if (! this._editor.getParam('size')) {
        xtdom.setAttribute(h, 'size', 8);
      }

    },

    // date picker event called before onClose if user hit Esc
    onEscape : function (num) {
      this.escape = true;
    },

    onClose : function () {
      this.stopEditing(this.escape);
      this.escape = false;
    },

    // Starts an edition session
    // Only setup field once
    startEditing : function (aEvent) {
      var min, max, before, h;
      xtiger.util.date.setRegion(this._editor.getParam('date_region'));
      if (! this.dpDone) {
        h = this._editor.getHandle();
        this.lazyInit(h);
        if (this.jhandle) {
          min = this._editor.getParam('minDate');
          max = this._editor.getParam('maxDate');
          before = this._editor.getParam('beforeShow');
          if (min) {
            min = (min === 'today') ? _genTodayFor(this._editor) : xtiger.util.date.convertDate(this._editor, min, 'date_format' , 'date_region');
            this.jhandle.datepicker('option', 'minDate', min);
          }
          if (max) {
            max = (max === 'today') ? _genTodayFor(this._editor) : xtiger.util.date.convertDate(this._editor, max, 'date_format' , 'date_region');
            this.jhandle.datepicker('option', 'maxDate', max);
          }
          if (before) {
            this.jhandle.datepicker('option', 'beforeShow', before);
          }
          $(h).datepicker('show');
        }
      }
    },

    // Stops the ongoing edition process
    stopEditing : function (isCancel) {
      var h = this._editor.getHandle();
          val = h.value;
      if (val.search(/\S/) === -1) { // space normalization
        val = ''; // will reset to default data
      }
      // incl. rough check on validity - FIXME: adjust to data_region / date_format ?
      if (val && ((val.length !== 10) || isCancel)) {
        h.value = this.model; // reset to previous value
      } else {
        this._editor.update(val);
        this.model = h.value;
      }
    },

    load : function (aPoint, aDataSrc) {
      var value, fallback,
          h = this._editor.getHandle();
      if (aPoint !== -1) {
        value = aDataSrc.getDataFor(aPoint);
        value = value ? ($.datepicker ? xtiger.util.date.convertDate(this._editor, value, 'date_format', 'date_region') : value ) : null;
        fallback = this.defaultData;
        h.value = value || fallback || '';
        this._editor.setModified(value !==  fallback);
        this._editor.set(false);
      } else {
        this.clear(false);
      }
      this.model = h.value;
    },

    save : function (aLogger) {
      var value = this._editor.getHandle().value;
      if (value) {
        value = $.datepicker ? xtiger.util.date.convertDate(this._editor, value, 'date_region', 'date_format') : value;
        aLogger.write(value);
      }
    }
  };

  //////////////////
  // Select Field //
  //////////////////

  // Internal class to manage an HTML input with a 'radio' or 'checkbox' type
  // cardinality is required for radio group when ?
  var _SelectField = function (editor, aType, aStamp) {
    var h = editor.getHandle(),
        name = editor.getParam('name'),
        card = editor.getParam('cardinality'),
        checked = editor.getParam('checked');
    this._editor = editor;
    this._type = aType;
    // xtdom.setAttribute(h, 'type', aType); (done in Generator because of IE < 9)
    if (name || (aType === 'radio')) {
      if (card) {
        aStamp = _getClockCount(name || 'void', card).toString(); // there should be a name
      }
      name = (name || '').concat(aStamp || '');
      xtdom.setAttribute(h, 'name', name);
      // xtiger.cross.log('debug', 'Created input type ' + aType + ' name=' + name);
    }
    if (checked) {
      if (checked === editor.getParam('value')) {
        h.checked = true; // xtdom.setAttribute(h, 'checked', true);
      } else {
        _encache(name, checked);
      }
    } else if (_decache(name, editor.getParam('value'))) {
      h.checked = true; // xtdom.setAttribute(h, 'checked', true);
    }
    if (editor.getParam('noedit') === 'true') {
      xtdom.addClassName(h, 'axel-input-unset');
    }
    // FIXME: transpose defaultData (checked attribute ?)
  };

  _SelectField.prototype = {

    awake : function () {
      // places an update call only for event filtering
      var h = this._editor.getHandle();
      var _this = this;
      xtdom.addEventListener(h, 'click',
        function(ev) {
          if (_this._editor.getHandle().checked) {
            _this._editor.update(_this._editor.getParam('value'));
          } else {
            _this._editor.update('');
          }
        }, true);
    },

    isFocusable : function () {
      return true;
    },

    load : function (aPoint, aDataSrc) {
      var found,
          h = this._editor.getHandle(),
          ischecked = false,
          value = this._editor.getParam('value'),
          checked;
      if (-1 !== aPoint) {
        found = aDataSrc.getDataFor(aPoint);
        ischecked = (found === value);
        if (!ischecked) { // store it for 2nd chance cache lookup
          name = this._editor.getParam('name');
          ischecked = _decache(name, value);
          _encache(name, found);
        }
        if (ischecked) { // checked
          if (! h.checked) {
            h.checked = true;
            this._editor.set(false);
            if (this._editor.getParam('noedit') === 'true') {
              xtdom.removeClassName(h, 'axel-input-unset');
            }
          }
        } else { // no checked
          this._editor.clear(false);
        }
      } else { // no value in XML input stream or 2nd chance
        checked = this._editor.getParam('checked');
        if (checked) { // MUST BE 1st input of the serie
          if (checked === value) {
            ischecked = true;
          } else {
            name = this._editor.getParam('name');
            _encache(name, checked);  // store it for 2nd chance cache lookup
          }
        } else { // try 2nd chance cache lookup
          name = this._editor.getParam('name');
          ischecked = _decache(name, value); 
        }
        if (ischecked) { // checked
          if (! h.checked) {
            h.checked = true;
            this._editor.set(false);
            if (this._editor.getParam('noedit') === 'true') {
              xtdom.removeClassName(h, 'axel-input-unset');
            }
          }
        } else { // no checked
          this._editor.clear(false);
        }
      }
      // FIXME: isModified is not accurate for this type of field since we do not track update
    },

    // FIXME: how to handle serialization to an xt:attribute
    save : function (aLogger) {
      var ed = this._editor;
      // TODO: serialize checkbox without value with no content or make value mandatory
      // si on accepte contenu vide pb est de faire le load, il faudra tester sur le nom de la balise (?)
      if (ed.getHandle().checked && (ed.getParam('noxml') !== 'true')) {
        aLogger.write(this._editor.getParam('value'));
      } else { // same as option="unset"
        aLogger.discardNodeIfEmpty();
      }
    },

    update : function (aData) {
      // nope
    },

    clear : function () {
      var h = this._editor.getHandle();
      if (this._editor.getParam('noedit') === 'true') {
        xtdom.addClassName(h, 'axel-input-unset');
      }
      h.checked = false;
    },

    focus : function () {
      this._editor.getHandle().focus();
    },

    unfocus : function () {
    }
  };

  ////////////////////////
  // The 'input' plugin //
  ////////////////////////
  var _Editor = {

    ////////////////////////
    // Life cycle methods //
    ////////////////////////

    onGenerate : function ( aContainer, aXTUse, aDocument ) {
      var pstr = aXTUse.getAttribute('param'), // IE < 9 does not render 'radio' or 'checkbox' when set afterwards
          tag = (!pstr || (pstr.indexOf('type=textarea') === -1)) ? 'input' : 'textarea',
          _handle = xtdom.createElement(aDocument, tag);
      if (pstr) {
        if (pstr.indexOf("type=radio") !== -1) {
          xtdom.setAttribute(_handle, 'type', 'radio');
        } else if (pstr.indexOf("type=checkbox") !== -1) {
          xtdom.setAttribute(_handle, 'type', 'checkbox');
        }
      }
      if (this.getParam('noedit') === 'true') {
        _handle.disabled = true;
      }
      aContainer.appendChild(_handle);
      return _handle;
    },

    onInit : function ( aDefaultData, anOptionAttr, aRepeater ) {
      var type, data;
      // create delegate
      type = this.getParam('type');
      if ((type === 'text') || (type === 'number') || (type === 'password') || (type === 'textarea')) {
        this._delegate = new _KeyboardField(this, type, aDefaultData);
      } else if ((type === 'radio') || (type === 'checkbox')) {
        this._delegate = new _SelectField(this, type, aRepeater ? aRepeater.getClockCount() : undefined);
      } else if (type === 'date') {
          this._delegate = new _DateField(this, type, aDefaultData);
      } else {
        xtdom.addClassName(this._handle, 'axel-generator-error');
        xtdom.setAttribute(this._handle, 'readonly', '1');
        xtdom.setAttribute(this._handle, 'value', 'ERROR: type "' + type + '" not recognized by plugin "input"');
        alert('Form generation failed : fatal error in "input" plugin declaration');
      }
      if (this.getParam('hasClass')) {
        xtdom.addClassName(this._handle, this.getParam('hasClass'));
      }
      // TBD: id attribute on handle (?)
    },

    onAwake : function () {
      this._delegate.awake();
    },

    onLoad : function (aPoint, aDataSrc) {
      this._delegate.load(aPoint, aDataSrc);
    },

    // Discards node if disabled (this is useful when used together with 'condition' binding)
    onSave : function (aLogger) {
      if (($(this.getHandle()).attr('disabled') === "disabled") || (this.isOptional() && !this.isSet())) {
        aLogger.discardNodeIfEmpty();
      } else {
        this._delegate.save(aLogger);
      }
    },

    ////////////////////////////////
    // Overwritten plugin methods //
    ////////////////////////////////
    api : {

      isFocusable : function () {
        return this._delegate.isFocusable();
      },

      focus : function () {
        if (this._delegate.focus) {
          this._delegate.focus();
        }
      },

      unfocus : function () {
        if (this._delegate.focus) {
          this._delegate.unfocus();
        }
      }
    },

    /////////////////////////////
    // Specific plugin methods //
    /////////////////////////////
    methods : {

      update : function (aData) {
        this._delegate.update(aData);
      },

      // Clears the model and sets its data to the default data.
      // Unsets it if it is optional and propagates the new state if asked to.
      clear : function (doPropagate) {
        this._delegate.clear();
        this.setModified(false);
        if (this.isOptional() && this.isSet()) {
          this.unset(doPropagate);
        }
      },

      // Overwrite 'optional' mixin method
      set : function(doPropagate) {
        // propagates state change in case some repeat ancestors are unset at that moment
        if (doPropagate) {
          if (!this.getParam('noedit')) {
            xtiger.editor.Repeat.autoSelectRepeatIter(this.getHandle());
          }
          xtdom.removeClassName(this._handle, 'axel-repeat-unset');
          // fix if *this* model is "placed" and the handle is outside the DOM at the moment
        }
        if (! this._isOptionSet) {
          this._isOptionSet = true;
          if (this._isOptional) {
            this._handle.disabled = false;
            this._optCheckBox.checked = true;
          }
        }
      },

      // Overwrite 'optional' mixin method
      unset : function (doPropagate) {
        if (this._isOptionSet) {
          this._isOptionSet = false;
          if (this._isOptional) {
            this._handle.disabled = true;
            this._optCheckBox.checked = false;
          }
        }
      }
    }
  };

  $axel.extend(_KeyboardField.prototype, _KeyboardMixinK);
  $axel.extend(_DateField.prototype, _KeyboardMixinK);

  $axel.plugin.register(
    'input',
    { filterable: true, optional: true },
    {
      type : 'text',
      date_region : 'fr',
      date_format : 'ISO_8601'
      // checked : 'false'
    },
    _Editor
  );
}($axel));
(function ($axel) {

  // you may use the closure to declare private objects and methods here

  var _Editor = {

    ////////////////////////
    // Life cycle methods //
    ////////////////////////
    onGenerate : function ( aContainer, aXTUse, aDocument ) {
      var viewNode = xtdom.createElement (aDocument, 'div');
      xtdom.addClassName(viewNode,'af-html');
      aContainer.appendChild(viewNode);
      return viewNode;
    },
    
    onInit : function ( aDefaultData, anOptionAttr, aRepeater ) {
      if (this.getParam('hasClass')) {
        xtdom.addClassName(this._handle, this.getParam('hasClass'));
      }
    },

    // Awakes the editor to DOM's events, registering the callbacks for them
    onAwake : function () {
    },

    onLoad : function (aPoint, aDataSrc) {
      var i, h;
      if (aDataSrc.isEmpty(aPoint)) {
        $(this.getHandle()).html('');
       } else {
         h = $(this.getHandle());
         h.html('');
         for (i = 1; i < aPoint.length; i++) {
           h.append(aPoint[i]);
         }
      }
    },

    onSave : function (aLogger) {
      aLogger.write('HTML BLOB');
    },

    ////////////////////////////////
    // Overwritten plugin methods //
    ////////////////////////////////
    api : {
    },

    /////////////////////////////
    // Specific plugin methods //
    /////////////////////////////
    methods : {
    }
  };

  $axel.plugin.register(
    'html', 
    { filterable: false, optional: false },
    { 
     key : 'value'
    },
    _Editor
  );

}($axel));/**
 * AXEL-FORMS "select2" filter
 *
 * Synopsis :
 *  - <xt:use types="choice" param="filter=select2"/>
 *
 */

/*****************************************************************************\
|                                                                             |
|  AXEL 'select2' filter                                                      |
|                                                                             |
|  Turns a 'choice' plugin into a select2 ComboBox                            |
|  See http://ivaynberg.github.io/select2/ for original select2               |
|  This is compatible with the patched version of select2 available           |
|  in the 3rd-part folder and/or at https://github.com/ssire/select2          |
|                                                                             |
|*****************************************************************************|
|  Prerequisite: check 3rd-part folder because you must include               |
|  select2.(min.)js together with AXEL-FORMS, you must also include           |
|  select2.(min.)css with your XTiger XML template file with select2.png,     |
|  select2x2.png, select2-spinner.gif available                               |
\*****************************************************************************/

// TODO:
// a- add a select2_ignoreAccents=true to decide wether or not to ignore accents
//    (now this is always the case)
// b- integrate filter parameters typing directly into AXEL (?)

// FIXME:
// a- select2 filtering is slow for long lists of options
//    see https://github.com/ivaynberg/select2/issues/781
//    at least we could cache the full query (for static lists)
//    (see updateResults function)
// b- .select2-results max-height could be adjusted dynamically depending
//    on space left to the bottom window on initial opening (using dropdownCss parameter)

(function ($axel) {
  
  // conversion table for extras select2 parameters
  var decodeTypes = {
    dropdownAutoWidth : 'bool',
    minimumResultsForSearch : 'int',
    closeOnSelect : 'bool',
    width : 'str',
    maximumSelectionSize : 'int',
    minimumInputLength : 'int'
  };

  function translate(source) {
    var i, cur, pos, res = '',
        from = 'ÀÁÂÃÄÅÒÓÔÕÕÖØÈÉÊËÇÐÌÍÎÏÙÚÛÜÑŠŸŽ',
        to = 'AAAAAAOOOOOOOEEEECDIIIIUUUUNSYZ';
    for (i = 0; i < source.length; i++) {
      cur = source.charAt(i).toUpperCase();
      pos = from.indexOf(cur);
      res += (pos >= 0) ? to.charAt(pos) : cur;
    }
    return res;
  }

  /* Copied and adapted from select2 
  */
  function markMatch(text, term, markup, escapeMarkup, match) {
    var tl=term.length;
    markup.push(escapeMarkup(text.substring(0, match)));
    markup.push("<span class='select2-match'>");
    markup.push(escapeMarkup(text.substring(match, match + tl)));
    markup.push("</span>");
    markup.push(escapeMarkup(text.substring(match + tl, text.length)));
  }

  function formatSelection (state, container) {
    var text, i, res;
    if ($.isArray(state) && state[0]) { // tags option for free text entry
      text = state[0].text || ''; // currently only multiple = 'no' supported
    } else {
      text = (state && state.text) ? state.text : '';
    }
    i = text.indexOf('::');      
    res = (i !== -1) ? text.substr(0, i) : text;
    return res;
  }

  function formatResult(state, container, query, escapeMarkup, openTag) {
    var text = (state && state.text) ? state.text : '',
        i = text.indexOf('::'),
        oTag = openTag || ' - <span class="select2-complement">',
        cTag = '</span>',
        qTerm = translate(query.term),
        match, markup;
    if (text) {
      markup=[];
      if (i !== -1 ) { // with complement
        if (query.term.length > 0) {
          match=translate(text).indexOf(qTerm);
          //match=$(state.element).data('key').indexOf(qTerm);
          if (match < i) {
            markMatch(text.substr(0, i), qTerm, markup, escapeMarkup, match);
            markup.push(oTag + escapeMarkup(text.substr(i + 2)) + cTag);
          } else if (match > i+1) {
            markup.push(text.substr(0, i));
            markup.push(oTag);
            markMatch(text.substr(i + 2), qTerm, markup, escapeMarkup, match-i-2);
            markup.push(cTag);
          } else {
            return escapeMarkup(text.substr(0, i)) + oTag + escapeMarkup(text.substr(i + 2)) + cTag;
          }
        } else {
          return escapeMarkup(text.substr(0, i)) + oTag + escapeMarkup(text.substr(i + 2)) + cTag;
        }
      } else if (query.term.length > 0) { // w/o complement with term
        match=translate(text).indexOf(qTerm);
        //match=$(state.element).data('key').indexOf(qTerm);
        if (match >= 0) {
          markMatch(text, qTerm, markup, escapeMarkup, match);
        } else {
          return text;
        }
      } else {
        return text;
      }
      return markup.join("");
    }
  }

  // Special matcher that does not care about latin accents 
  // uses a caching mechanism in case of option based selector
  // FIXME: update select2 to version 3.4.5 with stripDiacritics function
  function accentProofMatcher(term, text, option) {
    var key;
    if (option) {
      key = option.data("key");
      if (! key) {
        key = translate(text);
        option.data("key",key);
      }
    } else {
      key = translate(text);
    }
    return key.indexOf(translate(term))>=0;
  }
  
  function formatInputTooShort(input, min) { 
    var n = min - input.length;
    return xtiger.util.getLocaleString('hintMinInputSize', { 'n' : n });
  }

  var _Filter = {

    // rick to prevent cloning 'select2' shadow list when instantiated inside a repetition
    // the guard is needed to persist xttOpenLabel if planted on plugin
    onGenerate : function ( aContainer, aXTUse, aDocument ) {
      var res;
      if (this.getParam("select2_tags") === 'yes') { // do not take appearance into account
        res = xtdom.createElement (aDocument, 'input');
      } else {
        res = this.__select2__onGenerate(aContainer, aXTUse, aDocument);
      }
      aContainer.appendChild(res);
      $(res).wrap('<span class="axel-guard"/>');
      return res;
    },

    onAwake : function () {
      var  _this = this,
           defval = this.getDefaultData(),
           pl = this.getParam("placeholder"),
           klass = this.getParam("select2_complement"),
           tag = klass ? ' - <span class="' + klass + '">' : undefined,
           formRes = klass ? function (s, c, q, e) { return formatResult(s, c, q, e, tag); } : formatResult,
           params = {
             myDoc : this.getDocument(),
             formatResult: formRes,
             formatSelection : formatSelection,
             matcher : accentProofMatcher,
             formatInputTooShort : formatInputTooShort
           }, k, curVal, typVal;
      for (k in decodeTypes) { // FIXME: typing system to be integrated with AXEL
        curVal = this.getParam('select2_' + k);
        if (curVal) {
          if (decodeTypes[k] === 'bool') {
            typVal = curVal === 'true';
          } else if (decodeTypes[k] === 'int') {
            typVal = parseInt(curVal, 10);
          } else {
            typVal = curVal;
          }
          params[k] = typVal;
        }
      }
      if (this.getParam("select2_tags") === 'yes') { // not compatible with placeholder <- seems no longer true with S2 4.x
        params.multiple = false;
        params.tags = this.getParam('i18n');
        delete params.minimumResultsForSearch;
      } else {
        if (pl || (! defval)) {
          pl = pl || "";
          // inserts placeholder option
          if (this.getParam('multiple') !== 'yes') {
            $(this._handle).prepend('<option></option>');
          }
          // creates default selection
          if (!defval) {
            this._param.values.splice(0,0,pl);
            if (this._param.i18n !== this._param.values) { // FIXME: check it's correct
              this._param.i18n.splice(0,0,pl);
            }
          }
          params.allowClear = true;
          params.placeholder = pl;
        }
        if (this.getParam('multiple') !== 'yes') {
          if (this.getParam('typeahead') !== 'yes') {
            params.minimumResultsForSearch = -1; // no search box
          }
        }
      }
      this._setData(defval);
      $(this._handle).select2(params).change(
        function (ev, data) {
         if (!(data && data.synthetic)) { // short circuit if forged event (onLoad)
           _this.update($(this).val()); // tells 'choice' instance to update its model
         }
        }
      );
      $(this._handle).prev('.select2-container').get(0).xttNoShallowClone = true; // prevent cloning
    },

     // Triggers DOM 'change' event to tell model has changed to select2 implementation
     onLoad : function (aPoint, aDataSrc) {
       this.__select2__onLoad(aPoint,aDataSrc);
       $(this._handle).trigger("change", { synthetic : true });
     },
     
     ////////////////////////////////
     // Overwritten plugin methods //
     ////////////////////////////////
     
     api : {
       
       update : function (aData) {
         var _this = this;
         this.__select2__update(aData);
         setTimeout(function() { $(_this._handle).select2('focus'); }, 50);
         // keeps focus to be able to continue tabbing after drop list closing
       },

       focus : function () {
         $(this._handle).select2('focus');
       }
     },
     
     methods : {
     
       _setData : function ( value, withoutSideEffect ) {
         var filtered = value, i;
         if (this.getParam("select2_tags")) { // remove complement (see formatSelection)
           i = value.indexOf('::');
           if (i !== -1) {
             filtered = value.substr(0, i);
           }
         }
         this.__select2___setData(filtered, withoutSideEffect);
       }
      }
  };

  $axel.filter.register(
    'select2',
    { chain : [ 'update', 'onGenerate', 'onLoad', '_setData' ] },
    {
      select2_dropdownAutoWidth : 'false',
      select2_minimumResultsForSearch : '7',
      select2_closeOnSelect : 'false',
      select2_width : 'element',
      select2_maximumSelectionSize : '-1',
      select2_minimumInputLength : undefined
    },
    _Filter);
  $axel.filter.applyTo({'select2' : 'choice'});
}($axel));
/**
 * AXEL-FORMS "list" filter
 *
 * Synopsis :
 *  - <xt:use types="input" param="filter=list"/>
 *
 */

/*****************************************************************************\
|                                                                             |
|  AXEL 'list' filter                                                         |
|                                                                             |
|  Converts text entry into list entries with comma or space separator        |
|                                                                             |
|*****************************************************************************|
|  Prerequisites :                                                            |
\*****************************************************************************/
(function ($axel) {

  var _Filter = {
    
    // Turns <xvalue>X</xvalue>...<xvalue>Y</xvalue> input into 'X, ..., Y' string
    onLoad: function load (aPoint, aDataSrc) {
      var h, value, option, tmp,
          tag = this.getParam('xvalue');
      if (aDataSrc.isEmpty(aPoint) || !tag) { // default behavior
        this.__list__onLoad(aPoint, aDataSrc);
      } else { // decode content
        value = [];
        option = aDataSrc.getVectorFor(tag, aPoint);
        while (option !== -1) {
          tmp = aDataSrc.getDataFor(option);
          if (tmp) {
            value.push(tmp);
          }
          option = aDataSrc.getVectorFor(tag, aPoint);
        }
        value = value.join(', ');
        h = this.getHandle();
        fallback = this.getDefaultData() || '';
        this.getHandle().value = value || fallback || '';
        this.setModified(value !==  fallback);
        this.set(false);
      }
    },
    
    // DOES NOT forward the call unless missing 'xvalue' parameter
    onSave: function save (aLogger) {
      var tag, data, i,
          value = $.trim(this.getHandle().value);
      if ((!this.isOptional()) || this.isSet()) {
        if (value) {
          tag = this.getParam('xvalue');
          if (tag) {
            data = value.split(/\s*,\s*/);
            for (i=0; i < data.length; i++) {
              if (data[i] !== "") {
                aLogger.openTag(tag);
                aLogger.write(data[i]);
                aLogger.closeTag(tag);
              }
            }
          } else {
            this.__list__onSave(aLogger);
          }
        }
      } else {
        aLogger.discardNodeIfEmpty();
      }
    },

    methods : {
      update : function (aData) {
        var value = this.getHandle().value.split(/\s*,\s*/).join(', ');
        if ('true' === this.getParam('list_uppercase')) {
          value = value.toUpperCase();
        }
        this.getHandle().value = value;
        fallback = this.getDefaultData() || '';
        this.setModified(value !== fallback);
      }
    }
  };

  $axel.filter.register(
    'list',
    { chain : [ 'onLoad', 'onSave'] },
    null,
    _Filter);
  $axel.filter.applyTo({'list' : ['input']});
}($axel));/*****************************************************************************\
|                                                                             |
|  AXEL 'condition' binding                                                   |
|                                                                             |
|  Implements data-avoid-{variable} to disable fields on given data values    |
|  Applies to AXEL 'input' plugin                                             |
|                                                                             |
|*****************************************************************************|
|  Prerequisites: jQuery, AXEL, AXEL-FORMS                                    |
|                                                                             |
|  Limitations: one editor per page since it uses $('body') selector          |
|                                                                             |
\*****************************************************************************/
(function ($axel) {

  var _Condition = {

    onInstall : function ( host ) {
      this.avoidstr = 'data-avoid-' + this.getVariable();
      this.editor = $axel(host);
      host.bind('axel-update', $.proxy(this.updateConditionals, this));
      // command installation is post-rendering, hence we can change editor's state
      this.updateConditionals();
      // FIXME: should be optional (condition_container=selector trick as 'autofill' ?)
      $(document).bind('axel-content-ready', $.proxy(this, 'updateConditionals'));
      
    },

    methods : {

      updateConditionals : function  (ev, editor) {
        var onset, offset;
        var curval = this.editor.text();
        var fullset = $('body [' + this.avoidstr + ']', this.getDocument());
        onset = (curval != '') ? fullset.not('[' + this.avoidstr + '*="' + curval + '"]') : fullset.not('[' + this.avoidstr + '=""]');
        offset = (curval != '') ? fullset.filter('[' + this.avoidstr + '*="' + curval + '"]') : fullset.filter('[' + this.avoidstr + '=""]');
        onset.find('input').removeAttr('disabled');
        onset.css('color', 'inherit');
        offset.find('input').attr('disabled', 'disabled');
        offset.css('color', 'lightgray');
      }
    }
  };

  $axel.binding.register('condition',
    null, // no options
    null, // no parameters on host
    _Condition);

}($axel));
/*****************************************************************************\
|                                                                             |
|  AXEL 'interval' binding                                                    |
|                                                                             |
|  Implements data-min-date, data-max-date to define an interval              |
|  Applies to AXEL 'date' filter and 'input' sub-type 'date'                  |
|                                                                             |
|*****************************************************************************|
|  Prerequisites: jQuery, AXEL, AXEL-FORMS                                    |
|                                                                             |
\*****************************************************************************/

(function ($axel) {

  // FIXME: currenlty works only if date format on watched fields is ISO_8601 (aka YYYY-MM-DD)
  function parseDate(editor, date, defaults) {
    try {
      return date ? xtiger.util.date.convertDate(editor, date, 'date_format' , 'date_region') : defaults;
    }
    catch (e) {
      return defaults;
    }
  }

  var _Interval = {

    onInstall : function (host ) {
      var key = this.getVariable(),
          jmin = $('[data-min-date=' + key + ']', host.get(0)),
          jmax = $('[data-max-date=' + key + ']', host.get(0));
      this.min = $axel(jmin.get(0), true);
      this.max = $axel(jmax.get(0), true);
      this.min.configure('beforeShow', $.proxy(this.beforeShowMinDate, this));
      this.max.configure('beforeShow', $.proxy(this.beforeShowMaxDate, this));
    },

    methods : {

      // FIXME: adapt to format
      beforeShowMinDate : function ( input, picker ) {
        return { 'maxDate' : parseDate(this.max.get(0), this.max.text(), null) };
      },

      // FIXME: adapt to format
      beforeShowMaxDate : function ( input, picker ) {
        return { 'minDate' : parseDate(this.min.get(0), this.min.text(), null) };
      }
    }
  };

  $axel.binding.register('interval',
    null, // no options
    null, // no parameters on host
    _Interval
  );

}($axel));
/*****************************************************************************\
|                                                                             |
|  AXEL 'regexp' binding                                                      |
|                                                                             |
|                                                                             |
|*****************************************************************************|
|  Prerequisites: jQuery, AXEL, AXEL-FORMS                                    |
|                                                                             |
\*****************************************************************************/

// TODO: make data-regexp optional if data-pattern is defined for HTML5 validation only

(function ($axel) {

  var _Regexp = {

    onInstall : function ( host ) {
      var pattern = host.attr('data-pattern'),
          root, jroot;
      this.re = new RegExp(this.getParam('regexp') || '');
      this.editor = $axel(host);
      this.spec = host;
      host.bind('axel-update', $.proxy(this.checkRegexp, this));
      if (pattern) {
        host.find('input').attr("pattern", pattern); // adds HTML5 pattern attribute on input
      }
      $axel.binding.setValidation(this.editor.get(0), $.proxy(this.validate, this));
    },

    methods : {

      // Updates inline bound tree side-effects based on current data
      checkRegexp : function  () {
        var valid = this.re.test(this.editor.text()),
            scope, label, 
            doc = this.getDocument(),
            anchor = this.spec.get(0),
            vklass = this.spec.attr('data-valid-class'),
            iklass = this.spec.attr('data-invalid-class');
        if (vklass || iklass) {
          if (! this.errScope) { // search error in full document
            label = $('body ' + this.spec.attr('data-label-selector'), doc);
          } else { // search error within scope
            scope = $(anchor, doc).closest(this.errScope);
            label = $(this.spec.attr('data-label-selector'), scope.get(0));
          }
          if (vklass) {
            valid ? label.addClass(vklass) : label.removeClass(vklass);
          }
          if (iklass) {
            valid ? label.removeClass(iklass) : label.addClass(iklass);
          }
        }
        return this.toggleError(valid, this.editor.get(0).getHandle(true));
      },
      
      // Updates inline bound tree side-effects based on current data
      // Returns true to block caller command (e.g. save) if invalid
      // unless data-validation is 'off'
      validate : function () {
        var res = this.checkRegexp();
        return (this.spec.attr('data-validation') === 'off') || res;
      }
    }
  };

  $axel.binding.register('regexp',
    { error : true  }, // options
    { 'regexp' : $axel.binding.REQUIRED }, // parameters
    _Regexp
  );

}($axel));



/*****************************************************************************\
|                                                                             |
|  AXEL 'required' binding                                                    |
|                                                                             |
|  Makes a group of radio buttons or checkboxes required.                     |
|                                                                             |
|  Applies to a group of children AXEL 'input' plugins of type 'radio'        |
|  or 'checkbox'                                                              |
|                                                                             |
|*****************************************************************************|
|  Prerequisites: jQuery, AXEL, AXEL-FORMS                                    |
|                                                                             |
|  WARNING: experimental and tricky !                                         |
|  The binding registers itself on the DOM tree as a fake primitive editor    |
\*****************************************************************************/
(function ($axel) {

  var _Required = {

    onInstall : function ( host ) {
      this.editors = $axel(host);
      this.handle = host.get(0);
      if (this.handle.xttPrimitiveEditor) {
        xtiger.cross.log('error','Failed attempt to attach a "required" binding directly onto a primitive editor');
      } else {
        this.handle.xttPrimitiveEditor = this;
      }
    },

    methods : {

      isModified : function  () {
        var res = (this.editors.text() !== '')
        return res;
      },
      
      isFocusable : function () {
        var relay = this.editors.get(1); // 1 not 0 because the 1st one is the binding itsel faking a primitive editor
        return (relay && (relay !== this)) ? relay.isFocusable() : false;
      },
      
      focus : function () {
        var relay = this.editors.get(0);
        if (relay) {
          this.editors.get(0).focus()
        }
      },

      unfocus : function () {
        // should never be called
      },
      
      // DEPRECATED
      can : function (aFunction) {
        return false;
      },
      
      // required to display field name in validation
      getHandle : function () {
        return this.handle;
      },
      
      onInit : function ( aDefaultData, anOptionAttr, aRepeater ) {
      },
      
      onAwake : function () {
      },

      // FIXME: to be replaced by onSave
      load : function (aPoint, aDataSrc) {
      },
      
      // FIXME: to be replaced by onSave
      save : function (aLogger) {
      }      
    }
  };

  $axel.binding.register('required',
    { error : true  }, // options
    { 'required' : 'true' }, // parameters
    _Required
  );

}($axel));
/*****************************************************************************\
|                                                                             |
|  AXEL 'select' binding                                                      |
|                                                                             |
|  Turns checked property of target editors to true (iff target is enabled)   |
|  Applies to AXEL 'input' plugin with type to checkbox                       |
|                                                                             |
|*****************************************************************************|
|  Prerequisites: jQuery, AXEL, AXEL-FORMS                                    |
|                                                                             |
\*****************************************************************************/
(function ($axel) {

  var _Select = {

    onInstall : function ( host ) {
      this.host = host;
      this.editors = $axel(host);
      $('[data-select="' + this.getVariable() + '"]', this.getDocument()).bind('click', $.proxy(this, 'execute'));
    },

    methods : {
      execute : function  () {
        // FIXME: we should use the editor's API to change it's state instead
        this.editors.apply(function(n){ if (! n.disabled) { n.checked = true}}, true);
        $(this.host).triggerHandler('axel-select-all', [this]);
      }
    }
  };

  $axel.binding.register('select',
    null, // options
    null, // parameters
    _Select
  );

}($axel));
/*****************************************************************************\
|                                                                             |
|  'transform' command object                                                 |
|                                                                             |
|  Replaces host content by result of transformation of a template.           |
|  This is NOT an interactive command: it does not subscribe to user event.   |
|                                                                             |
|*****************************************************************************|
|  Command is executed :                                                      |
|  - by AXEL-FORMS document load handler to transform any host element with   |
|    data-template but w/o data-command="transform" (implicit creation)       |
|  - by calling the transform() method if it has been created as a result     |
|    of a data-command="transform" declaration                                |
|                                                                             |
|  Required attributes                                                        |
|  - data-template : sets the URL for the template to transform               |
|                                                                             |
|  Optional attributes                                                        |
|  - data-src                                                                 |
|  - data-transaction                                                         |
|  - data-cancel                                                              |
|                                                                             |
\*****************************************************************************/

(function () {

  function TransformCommand ( identifier, node, doc ) {
    var spec = $(node);
    this.doc = doc;
    this.key = identifier;
    this.spec = spec;
    if (spec.attr('data-command') !== 'transform') { // implicit command (data-template alone)
      // xtiger.cross.log('debug','Transforming ' + identifier + ' in implicit mode');
      this.transform();
      this.implicit = true;
    } else {
      // xtiger.cross.log('debug','Transforming ' + identifier + ' in explicit mode');
      this.implicit = false;
    }
    this.defaultTpl = this.spec.attr('data-template');
    this.defaultData = this.spec.attr('data-src') || '';
    this.ready = false;
  }

  TransformCommand.prototype = {

    getDefaultTemplate : function () { return  this.defaultTpl; },

    getDefaultSrc : function () { return  this.defaultData; },

    attr : function (name) {
      if (arguments.length >1) {
        return this.spec.attr(name, arguments[1]);
      } else {
        return this.spec.attr(name);
      }
    },
    
    transform : function (tOptUrl, dOptUrl) {
      var name, set, config,
          templateUrl = tOptUrl || this.spec.attr('data-template'), // late binding
          dataUrl = dOptUrl || this.spec.attr('data-src'); // late binding
      if ((templateUrl === this.spec.attr('data-template')) && this.ready) {
        if (dOptUrl) {
          this.spec.attr('data-src', dOptUrl);
        }
        this.reset();
      } else {
        if (templateUrl) {
          // 1. adds a class named after the template on 'body' element
          // FIXME: could be added to the div domContainer instead ?
          if (templateUrl !== '#') {
            name = templateUrl.substring(templateUrl.lastIndexOf('/') + 1);
            if (name.indexOf('?') !== -1) {
              name = name.substring(0, name.indexOf('?'));
            }
          }

          // 2. loads and transforms template and optionnal data
          config = {
            bundlesPath : $axel.command.defaults.bundlesPath,
            enableTabGroupNavigation : true
          };
          set = (templateUrl === '#') ? $axel(this.spec).transform(config) : $axel(this.spec).transform($axel.resolveUrl(templateUrl,this.spec.get(0)), config);

          if (dataUrl) {
            set.load($axel.resolveUrl(dataUrl, this.spec.get(0)));
            this.spec.attr('data-src', dataUrl);
          }

          // 3. registers optional unload callback if transactionnal style
          if (this.spec.attr('data-cancel')) {
            $(window).bind('unload', $.proxy(this, 'reportCancel'));
            // FIXME: works only if self-transformed and called ONCE !
          }

          // 4. triggers completion event
          if (set.transformed()) {
            if (! this.implicit) {
              // xtiger.cross.log('debug', '[[[ installing bindings from "transform" command');
              $axel.binding.install(this.doc, this.spec.get(0), this.spec.get(0));
              // xtiger.cross.log('debug', ']]] installed bindings from "transform" command');
              // xtiger.cross.log('debug', '<<< installing commands from "transform" command');
              $axel.command.install(this.doc, this.spec.get(0).firstChild, this.spec.get(0).lastChild);
              // xtiger.cross.log('debug', '>>> installed commands from "transform" command');
            }
            this.spec.attr('data-template', templateUrl);
            this.spec.addClass('edition').addClass(name); // FIXME: remove .xhtml
            this.ready = true;
          } else {
            this.ready = false;
          }
        } else {
          $axel.error('Missing data-template attribute to generate the editor "' + this.key + '"');
        }
      }
    },

    // Remove all data from the editor
    // If hard is true and the command was holding a data-template, restores it
    // FIXME: replace by $axel(this.spec).reset() with builtin reset algorithm
    reset : function (hard) {
      var src;
      if (hard && this.defaultTpl && (this.defaultTpl !== his.spec.attr('data-template'))) { // last test to avoid loop
        this.attr('data-src', this.defaultData);
        this.transform($axel.resolveUrl(this.defaultTpl, this.spec.get(0)));
      } else {
        src = this.spec.attr('data-src');
        if (src) {
          $axel(this.spec).load($axel.resolveUrl(src, this.spec.get(0)));
        } else {
          $axel(this.spec).load('<Reset/>'); // trick  
        }
        $('*[class*="af-invalid"]', this.spec.get(0)).removeClass('af-invalid');
        $('*[class*="af-required"]', this.spec.get(0)).removeClass('af-required');
      }
    },
    
    reload : function () {
      var url = this.spec.attr('data-src');
      $('*[class*="af-invalid"]', this.spec.get(0)).removeClass('af-invalid');
      $('*[class*="af-required"]', this.spec.get(0)).removeClass('af-required');
      if (url) {
        $axel(this.spec).load($axel.resolveUrl(url, this.spec.get(0)));
      }
    },
    
    // Loads data into the editor and set it as the new data source
    load : function (src) {
      var wrapper = $axel(this.spec);
      $('*[class*="af-invalid"]', this.spec.get(0)).removeClass('af-invalid');
      $('*[class*="af-required"]', this.spec.get(0)).removeClass('af-required');
      wrapper.load('<Reset/>'); // TODO: clear()
      if (src) {
        wrapper.load($axel.resolveUrl(src, this.spec.get(0)))
      }
      this.attr('data-src', src);
    },

    // Triggers an event on the host node only (no bubbling)
    // FIXME: use a data hash to pass named properties { editor: XXX, source: XXX, xhr: XXX } ?
    trigger : function (name, source, extra) {
      this.spec.triggerHandler(name, [this, source, extra]);
    },

    // DEPRECATED : use $axel(~data-target~).xml() instead
    serializeData : function () {
      return $axel(this.spec).xml();
    },
    
    reportCancel : function (event) {
      if (! this.hasBeenSaved) { // trick to avoid cancelling a transaction that has been saved
        $.ajax({
          url : this.spec.attr('data-cancel'),
          data : { transaction : this.spec.attr('data-transaction') },
          type : 'GET',
          async : false
          });
      }
    }
  };

  $axel.command.register('transform', TransformCommand, { check : false });
}());
/*****************************************************************************\
|                                                                             |
|  'reset' command object                                                     |
|                                                                             |
|*****************************************************************************|
|                                                                             |
|  Required attributes :                                                      |
|  - data-target : id of the editor's container                               |
|                                                                             |
\*****************************************************************************/

// TODO :
// currently this does not work if the data-target editor has been generated
// from the document itself (i.e. data-template="#")

(function () {
  
  function ResetCommand ( identifier, node ) {
    this.key = identifier; /* data-target */
    $(node).bind('click', $.proxy(this, 'execute'));
  }
  
  ResetCommand.prototype = {
    execute : function (event) {
      var verr, editor = $axel.command.getEditor(this.key);
      if (editor) {
        editor.reset();
        verr = editor.attr('data-validation-output'); // FIXME: document ?
        if (verr) {
          $('#' + verr).removeClass('af-validation-failed');
        }
      }
    }
  };
  
  $axel.command.register('reset', ResetCommand, { check : true });
}());/*****************************************************************************\
|                                                                             |
|  'save' command object (XML submission with Ajax a form)                    |
|                                                                             |
|*****************************************************************************|
|                                                                             |
|  Required attributes :                                                      |
|  - data-target : id of the editor's container to generate submission data   |
|                                                                             |
|  Optional attributes :                                                      |
|  - data-replace-type : defines what to do with the servers's response       |
|    value is 'event' and/or a choice of 'all', 'swap', 'append', 'prepend'   |
|  - data-event-target : when data-replace-type is 'event' this attribute     |
|    gives the name of a second editor from which to trigger a copy cat of    |
|    'axel-save-done' event (e.g. to trigger refresh content)                 |
|  - data-validation-output (on the target editor): identifier of a target    |
|    element to use as a container for showing validation error messages,     |
|    the presence of this attribute causes validation                         |
|                                                                             |
|  HTTP Responses :                                                           |
|  - redirection with Location header                                         |
|  - <success> with <message>, <payload> and /or <forward> elements           |
|  - <error> with <message> in case of server-side error                      |
|                                                                             |
\*****************************************************************************/

(function () {
  
  function SaveCommand ( identifier, node, doc ) {
    this.doc = doc || document;
    this.spec = $(node);
    this.key = identifier;
    this.spec.bind('click', $.proxy(this, 'execute'));
  }
  
  SaveCommand.prototype = (function () {

    // Implements data-replace-type feedback from ajax response
    function doIncUpdate ( type, xhr ) {
      var content;
      if (/all|swap|append|prepend/.test(type)) { // incremental update
        content = $axel.oppidum.unmarshalPayload(xhr);
        fnode = $('#' + this.spec.attr('data-replace-target'));
        if (fnode.length > 0) {
          if (type.indexOf('all') !== -1) {
            fnode.replaceWith(content);
          } else if (type.indexOf('swap') !== -1) {
            this.swap = $(content); // FIXME: document context ?
            fnode.after(this.swap);
            fnode.hide();
            this.fragment = fnode; // cached to implement data-command="continue"
            $('button[data-command="continue"]', this.swap).bind('click', $.proxy(doSwap, this));
            $('button[data-command="reset"]', this.swap).bind('click', $.proxy(doReset, this));
          } else if (type.indexOf('append') !== -1) {
            fnode.append(content);
          } else if (type.indexOf('prepend') !== -1) {
            fnode.prepend(content);
          } 
          // TBD: before, after
        } else { 
          xtiger.cross.log('error', 'missing "data-replace-target" attribute to report "save" command success');
        }
      }
    }

    function doSwap () {
      this.swap.remove();
      this.fragment.show();
    }

    function doReset () {
      var editor = $axel.command.getEditor(this.key);
      if (editor) {
        editor.reset();
        this.swap.remove();
        this.fragment.show();
      } else {
        $axel.error(xtiger.util.getLocaleString("editorNotFound"));
      }
    }

    function saveSuccessCb (response, status, xhr, memo) {
      var type, msg, tmp, proceed, cmd;

      // 1) middle of transactional protocol
      if ((xhr.status === 202) && memo) {
        cmd = $axel.oppidum.getCommand(xhr);
        proceed = confirm($axel.oppidum.decodeMessage(cmd));
        if (memo.url.indexOf('?') !== -1) {
          tmp = memo.url + '&_confirmed=1';
        } else {
          tmp = memo.url + '?_confirmed=1';
        }
        if (proceed) {
          $.ajax({
            url : tmp,
            type : memo.method,
            data :  memo.payload,
            cache : false,
            timeout : 50000,
            dataType : 'xml',
            contentType : "application/xml; charset=UTF-8",
            success : $.proxy(saveSuccessCb, this),
            error : $.proxy(saveErrorCb, this)
          });
          return; // short-circuit final call to finished
        } else {
          $axel.command.getEditor(this.key).trigger('axel-save-cancel', this, xhr);
        }

      // 2) direct response or end of transactionnal protocol
      } else if ((xhr.status === 201) || (xhr.status === 200)) {
        cmd = $axel.oppidum.getCommand(xhr);
        if ($axel.oppidum.filterRedirection(cmd)) { // in page feedback
          $axel.oppidum.handleMessage(cmd); // <message> feedback
          // <payload> feedback
          type = this.spec.attr('data-replace-type') || 'all';
          doIncUpdate.call(this, type, xhr);
          // 'axel-save-done' event dispatch
          $axel.command.getEditor(this.key).trigger('axel-save-done', this, xhr);
          if (type.indexOf('event') !== -1) { // optional secondary target editor
            // FIXME: adjust editor's trigger method to add arguments... (e.g. event payload ?)
            tmp = this.spec.attr('data-event-target');
            if (tmp) {
              tmp = $axel.command.getEditor(tmp);
              if (tmp) {
                tmp.trigger('axel-save-done', this, xhr);
              }
            }
          }
        }

      // 3) untrapped server-side error or wrong Ajax protocol error
      } else {
        $axel.error(xtiger.util.getLocaleString('errServerResponse', { 'xhr' : xhr }));
        $axel.command.getEditor(this.key).trigger('axel-save-error', this, xhr);
      }

      // 4) re-enable 'save' command
      finished(this);
      
      if (cmd) {
        $axel.oppidum.handleForward(cmd); // <forward> feedback
      }
    }

    function saveErrorCb (xhr, status, e) {
      var msg,
          flags = this.spec.attr('data-save-flags');
      if ((!flags) || flags.indexOf('silentErrors') === -1) {
        msg = $axel.oppidum.parseError(xhr, status, e);
        $axel.error(msg);
      } else {
        this.spec.trigger('axel-network-error', { xhr : xhr, status : status, e : e });
      }
      $axel.command.getEditor(this.key).trigger('axel-save-error', this, xhr);
      finished(this);
    }

    function started (that) {
      var flags = that.spec.attr('data-save-flags');
      if (flags && flags.indexOf('disableOnSave') != -1) {
        that.spec.attr('disabled', 'disable');
      }
      that.spec.addClass('axel-save-running');
    }

    function finished (that) {
      var flags = that.spec.attr('data-save-flags');
      if (flags && flags.indexOf('disableOnSave') != -1) {
        that.spec.removeAttr('disabled');
      }
      that.spec.removeClass('axel-save-running');
    }

    return {
      execute : function (event) {
        var method, dataUrl, transaction, data, fields, _successCb, _memo,
            _this = this,
            valid = true,
            editor = $axel.command.getEditor(this.key),
            yesNo = this.spec.attr('data-save-confirm'),
            type = this.spec.attr('data-type');
        if (editor) {
          if (!yesNo || confirm(yesNo)) {
            url = this.spec.attr('data-src') || editor.attr('data-src') || '.'; // last case to create a new page in a collection
            if (url) {
              if (editor.attr('data-validation-output') || this.spec.attr('data-validation-output')) {
                fields = $axel(editor.spec.get(0)); // FIXME: define editor.getRoot()
                valid = $axel.binding.validate(fields,
                  editor.attr('data-validation-output')  || this.spec.attr('data-validation-output'),
                  this.doc, editor.attr('data-validation-label')  || this.spec.attr('data-validation-label'));
              }
              if (valid) {
                data = editor.serializeData();
                if (data) {
                  method = editor.attr('data-method') || this.spec.attr('data-method') || 'post';
                  transaction = editor.attr('data-transaction') || this.spec.attr('data-transaction');
                  if (transaction) {
                    url = url + '?transaction=' + transaction;
                  }
                  url = $axel.resolveUrl(url, this.spec.get(0));
                  started(this);
                  $axel.command.getEditor(this.key).trigger('axel-save', this);
                  _memo = { url : url, payload : data, method : method };
                  _successCb = function (data, textStats, jqXHR) {
                                 saveSuccessCb.call(_this, data, textStats, jqXHR, _memo);
                               };
                  $.ajax({
                    url : url,
                    type : method,
                    data : data,
                    dataType : type || 'xml', // FIXME: _memo
                    cache : false,
                    timeout : 50000,
                    contentType : "application/xml; charset=UTF-8",
                    success : _successCb,
                    error : $.proxy(saveErrorCb, this)
                    });
                    editor.hasBeenSaved = true; // trick to cancel the "cancel" transaction handler
                } else {
                  $axel.error(xtiger.util.getLocaleString("editorEmpty"));
                }
              }
            } else {
              $axel.error(xtiger.util.getLocaleString("noTargetURL"));
            }
          }
        } else {
          $axel.error(xtiger.util.getLocaleString("editorNotFound"));
        }
      }
    };
  }());

  $axel.command.register('save', SaveCommand, { check : false });
}());
/*****************************************************************************\
|                                                                             |
|  'submit' command object (XML submission through a form)                    |
|                                                                             |
|*****************************************************************************|
|                                                                             |
|  Required attributes :                                                      |
|  - data-target : id of the editor's container                               |
|  - data-form : id of the form to use for submission to the serevr           |
|                                                                             |
\*****************************************************************************/
(function () {

  function SubmitCommand ( identifier, node ) {
    var spec = $(node);
    this.key = identifier; /* data-target */
    this.formid = spec.attr('data-form');
    if (this.formid && ($('form#' + this.formid).length > 0)) { // checks form element existence
      node.disabled = false;
      spec.bind('click', $.proxy(this, 'execute'));
    } else {
      node.disabled = true;
      $axel.error('Missing or invalid data-form attribute in submit command ("' + this.formid + '")');
    }
  }

  SubmitCommand.prototype = {
    // Saves using a pre-defined form element identified by its id
    // using a 'data' input field (both must be defined)
    // Note in that case there is no success/error feedback
    execute : function () {
      var f = $('#' + this.formid),
          d = $('#' + this.formid + ' > input[name="data"]' ),
          editor = $axel.command.getEditor(this.key);
      if (editor && (f.length > 0) && (d.length > 0)) {
        d.val(editor.serializeData());
        f.submit();
      } else {
        $axel.error('Missing editor or malformed form element to submit data');
      }
    }
  };

  $axel.command.register('submit', SubmitCommand, { check : true });
}());/*****************************************************************************\
|                                                                             |
|  'trigger' command object                                                   |
|                                                                             |
|*****************************************************************************|
|                                                                             |
|  Required attributes :                                                      |
|  - data-target : id of the editor where to send the event                   |
|  - data-trigger-event : event name to propagate                             |
|                                                                             |
\*****************************************************************************/
(function () {
  function TriggerCommand ( identifier, node ) {
    this.spec = $(node);
    this.key = identifier;
    this.spec.bind('click', $.proxy(this, 'execute'));
  }

  TriggerCommand.prototype = {
    execute : function (event) {
      $axel.command.getEditor(this.key).trigger(this.spec.attr('data-trigger-event'), this);
    }
  };

  $axel.command.register('trigger', TriggerCommand, { check : false });
}());
/*****************************************************************************\
|                                                                             |
|  'add' command object                                                       |
|                                                                             |
|*****************************************************************************|
|                                                                             |
|  Required attributes :                                                      |
|  - data-target : id of the editor where to send the event                   |
|                                                                             |
|  Then choose one of the two editing modes below :                           |
|  - data-target-ui : id of the div to show when editing                      |
|   (and to hide when not editing)                                            |
|  - data-target-modal : id of the (Bootstrap) modal window to use for        |
|    editing                                                                  |
|                                                                             |
|  Optional attribute :                                                       |
|  - data-src : url of the controller where to send the edited data           |
|   use this if the target editor's data-src is not pre-defined               |
|  - data-edit-action (create | update) : when using data-src this mandatory  |
|   attribute defines if the data-src attribute must be pre-loaded (update)   |
|   or not (create)                                                           |
|  - data-add-key="xxx" : works in conjunction with data-title-scope          |
|    to locate data-when-{xxx} and change an optional editor's window title   |
|                                                                             |
\*****************************************************************************/
(function () {
  function AddCommand ( identifier, node ) {
    this.spec = $(node);
    this.key = identifier;
    this.spec.bind('click', $.proxy(this, 'execute'));
    $('#' + identifier).bind('axel-cancel-edit', $.proxy(this, 'dismiss'));
    $('#' + identifier).bind('axel-save-done', $.proxy(this, 'saved'));
  }
  AddCommand.prototype = {
    execute : function (event) {
      var dial, tmp, title,
          ed = $axel.command.getEditor(this.key),
          action = this.spec.attr('data-edit-action');
      if (action) {
        if (action === 'update') {
          ed.attr('data-src', this.spec.attr('data-src')); // preload XML data
        } else if (action === 'create') {
          ed.attr('data-src', ''); // to prevent XML data loading
        }
      }
      if (!this.done || !ed.getDefaultTemplate()) { // most probably a shared editor
        // resolves optional data-with-template relatively to command button host else falls back to 'transform' data-template
        tmp = this.spec.attr('data-with-template');
        ed.transform(tmp ? $axel.resolveUrl(tmp, this.spec.get(0)) : undefined ); 
      } else if (this.cleanOnShow) {
        ed.reset();
        this.cleanOnShow = false;
      }
      // try to change editor's title using a mode key
      tmp = this.spec.attr('data-add-key');
      if (tmp) {
        tmp = 'data-when-' + tmp;
        title = $('#' + this.spec.attr('data-title-scope')).find('[' + tmp + ']');
        title.text(title.attr(tmp));
      }
      if ($axel('#' + this.key).transformed()) { // assumes synchronous transform()
        this.done = true;
        dial = this.spec.attr('data-target-modal');
        if (action === 'create') {
          ed.attr('data-src', this.spec.attr('data-src'));
        }
        if (dial) {
          $('#' + dial).modal('show').one('hidden', $.proxy(this, 'hidden'));
          this.spec.get(0).disabled = true;
        } else {
          $('#' + this.spec.attr('data-target-ui')).show();
          this.spec.hide();
        }
      }
    },
    dismiss : function (event) {
      var dial;
      dial = this.spec.attr('data-target-modal');
      if (dial) {
        $('#' + dial).modal('hide');
      } else {
        $('#' + this.spec.attr('data-target-ui')).hide();
        this.spec.show();
      }
    },
    saved : function (event) {
      this.dismiss();
      this.cleanOnShow = true;
    },
    hidden : function () { // modal hidden
      this.spec.get(0).disabled = false;
    }
  };
  $axel.command.register('add', AddCommand, { check : true });
}());
/**
 * AXEL-FORMS English translation.
 *
 * Author: Stéphane Sire <s.sire@oppidoc.fr>
 */
(function ($axel) {
  $axel.addLocale('en',
    {
      // Functions with values
      errFormRequired : function (values) {
        return "You must fill the following fields : " + values.fields; },
      errFormInvalid : function (values) {
        return "You must correct the following fields : " + values.fields; },
      hintMinInputSize : function (values) { 
        return "Type at least " + values.n + " letter" + (values.n === 1? "" : "s"); },
      errServerResponse : function (values) {
        return "Unexpected response from server (" + values.xhr ? values.xhr.status : "undefined" + "). The action may have failed"; },

      // Simple strings
      errServerTimeOut : "Action aborted: server is taking too much time to answer. You should reload the page to check if the action has been executed anyway",
      msgRedirect : "You are going to be redirected",
      editorEmpty : "The document contains no data",
      noTargetURL : "The command does not know where to send the data",
      editorNotFound : "There is no editor associated with this command"
    }
  );
}($axel));/**
 * AXEL-FORMS French translation.
 *
 * Author: Stéphane Sire <s.sire@oppidoc.fr>
 */
(function ($axel) {
  $axel.addLocale('fr',
    {
      // Functions with values
      errFormRequired : function (values) {
        return "Vous devez remplir les champs suivants : " + values.fields; },
      errFormInvalid : function (values) {
        return "Vous devez corriger les champs suivants : " + values.fields; },
      hintMinInputSize : function (values) { 
        return "Entrez au moins " + values.n + " caractère" + (values.n === 1? "" : "s"); },
      errServerResponse : function (values) {
        return "Mauvaise réponse du serveur (" + values.xhr ? values.xhr.status : "undefined" + "). L'action a peut-être échoué"; }, 

      // Simple strings
      errServerTimeOut : "Action annulée, délai de réponse dépassé. Rechargez la page pour vérifier si votre action a été prise en compte.",
      msgRedirect : "Vous allez être redirigé",
      editorEmpty : "Le document est vide",
      noTargetURL : "La commande ne sait pas où envoyer les données",
      editorNotFound : "Il n'y a pas d'éditeur associé avec cette commande"
    }
  );
}($axel));