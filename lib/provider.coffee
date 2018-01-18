COMPLETIONS = require '../completions.json'

attributePattern = /\s+([a-z][-a-z]*)\s*=\s*$/
tagPattern = /(?:\[|@)+(([a-z]+_*)*[a-z]+_*)(?:\s|$)/

module.exports =
  selector: '.source.ks'
  disableForSelector: '.source.ks .comment'
  filterSuggestions: true
  completions: COMPLETIONS

  getSuggestions: (request) ->
    if @isAttributeValueStart(request)
      @getAttributeValueCompletions(request)
    else if @isAttributeStart(request)
      @getAttributeNameCompletions(request)
    else if @isTagStart(request)
      @getTagNameCompletions(request)
    else
      []

  onDidInsertSuggestion: ({editor, suggestion}) ->
    setTimeout(@triggerAutocomplete.bind(this, editor), 1) if suggestion.type is 'attribute'

  triggerAutocomplete: (editor) ->
    atom.commands.dispatch(atom.views.getView(editor), 'autocomplete-plus:activate', activatedManually: false)

  isTagStart: ({prefix, scopeDescriptor, bufferPosition, editor}) ->
    return @hasTagScope(scopeDescriptor.getScopesArray()) if prefix.trim() and prefix.indexOf('\[') is -1 and prefix.indexOf('@') is -1
    prefix = editor.getTextInRange([[bufferPosition.row, bufferPosition.column - 1], bufferPosition])
    scopes = scopeDescriptor.getScopesArray()
    (prefix is '\[' or prefix is '@') and scopes[0] is 'source.ks' and scopes.length is 1

  isAttributeStart: ({prefix, scopeDescriptor, bufferPosition, editor}) ->
    scopes = scopeDescriptor.getScopesArray()
    return @hasTagScope(scopes) if not @getPreviousAttribute(editor, bufferPosition) and prefix and not prefix.trim()

    previousBufferPosition = [bufferPosition.row, Math.max(0, bufferPosition.column - 1)]
    previousScopes = editor.scopeDescriptorForBufferPosition(previousBufferPosition)
    previousScopesArray = previousScopes.getScopesArray()

    return true if previousScopesArray.indexOf('entity.other.attribute-name.ks') isnt -1
    return false unless @hasTagScope(scopes)

    scopes.indexOf('punctuation.definition.tag.end.ks') isnt -1 and
      previousScopesArray.indexOf('punctuation.definition.tag.end.ks') is -1

  isAttributeValueStart: ({scopeDescriptor, bufferPosition, editor}) ->
    scopes = scopeDescriptor.getScopesArray()
    previousBufferPosition = [bufferPosition.row, Math.max(0, bufferPosition.column - 1)]
    previousScopes = editor.scopeDescriptorForBufferPosition(previousBufferPosition)
    previousScopesArray = previousScopes.getScopesArray()

    @hasStringScope(scopes) and @hasStringScope(previousScopesArray) and
      previousScopesArray.indexOf('punctuation.definition.string.end.ks') is -1 and
      @hasTagScope(scopes) and
      @getPreviousAttribute(editor, bufferPosition)?

  hasTagScope: (scopes) ->
    for scope in scopes
      return true if scope.startsWith('meta.tag.') and scope.endsWith('.ks')
    return false

  hasStringScope: (scopes) ->
    scopes.indexOf('string.quoted.double.ks') isnt -1 or
      scopes.indexOf('string.quoted.single.ks') isnt -1

  getTagNameCompletions: ({prefix, editor, bufferPosition}) ->
    tmpPrefix = editor.getTextInRange([[bufferPosition.row, bufferPosition.column - 1], bufferPosition])
    ignorePrefix = tmpPrefix is '\[' or tmpPrefix is '@'

    completions = []
    for tag, options of @completions.tags when ignorePrefix or firstCharsEqual(tag, prefix)
      completions.push(@buildTagCompletion(tag, options))
    completions

  buildTagCompletion: (tag, {description}) ->
    text: tag
    type: 'tag'
    description: description ? "タグ"
    descriptionMoreURL: if description then @getTagDocsURL(tag) else null

  getAttributeNameCompletions: ({prefix, editor, bufferPosition}) ->
    completions = []
    tag = @getPreviousTag(editor, bufferPosition)
    tagAttributes = @getTagAttributes(tag)

    for attribute in tagAttributes when not prefix.trim() or firstCharsEqual(attribute[0], prefix)
      completions.push(@buildAttributeCompletion(attribute, tag, @completions.attributes[tag+'/'+attribute[0]]))

    completions

  buildAttributeCompletion: (attribute, tag, options) ->
    snippet: if options?.type is 'flag' then attribute[0] else "#{attribute[0]}=\"$1\"$0"
    displayText: attribute[0]
    type: 'attribute'
    rightLabel: if attribute[1] is '*' then '*必須' else ''
    description: options?.description ? "[#{tag}] パラメータ"
    descriptionMoreURL: @getTagDocsURL(tag)

  getAttributeValueCompletions: ({prefix, editor, bufferPosition}) ->
    completions = []
    tag = @getPreviousTag(editor, bufferPosition)
    attribute = @getPreviousAttribute(editor, bufferPosition)
    values = @getAttributeValues(tag, attribute)

    for value in values when not prefix or firstCharsEqual(value, prefix)
      completions.push(@buildAttributeValueCompletion(tag, attribute, value))

    completions

  buildAttributeValueCompletion: (tag, attribute, value) ->
        text: value
        type: 'value'
        description: options?.description ? "[#{tag}] パラメータ"
        descriptionMoreURL: @getTagDocsURL(tag)

  getPreviousTag: (editor, bufferPosition) ->
    {row} = bufferPosition
    while row >= 0
      tag = tagPattern.exec(editor.lineTextForBufferRow(row))?[1]
      return tag if tag
      row--
    return

  getPreviousAttribute: (editor, bufferPosition) ->
    quoteIndex = bufferPosition.column - 1
    while quoteIndex
      scopes = editor.scopeDescriptorForBufferPosition([bufferPosition.row, quoteIndex])
      scopesArray = scopes.getScopesArray()
      break if not @hasStringScope(scopesArray) or scopesArray.indexOf('punctuation.definition.string.begin.ks') isnt -1
      quoteIndex--

    attributePattern.exec(editor.getTextInRange([[bufferPosition.row, 0], [bufferPosition.row, quoteIndex]]))?[1]

  getAttributeValues: (tag, attribute) ->
    @completions.attributes[tag+'/'+attribute]?.attribOption ? @completions.attributes["#{tag}/#{attribute}"]?.attribOption ? []

  getTagAttributes: (tag) ->
    @completions.tags[tag]?.attributes ? []

  getTagDocsURL: (tag) ->
    "https://tyrano.jp/tag\##{tag}"

firstCharsEqual = (str1, str2) ->
  str1[0].toLowerCase() is str2[0].toLowerCase()
