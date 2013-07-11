#= require ./flexible_text_field

Emberella = window.Emberella
jQuery = window.jQuery
get = Ember.get
set = Ember.set
typeOf = Ember.typeOf

DEFAULT_DELIMITER = ','

Emberella.TagItemView = Ember.View.extend Ember.StyleBindingsMixin, Emberella.FocusableMixin, Emberella.KeyboardControlMixin,
  tagName: 'span'
  classNames: ['emberella-tag-item']
  styleBindings: ['display']

  tabindex: -1

  content: null

  deleteCharacterBinding: 'parentView.deleteCharacter'
  deleteTitleBinding: 'parentView.deleteTitle'

  display: Ember.computed ->
    content = jQuery.trim get(@, 'content')
    'none' unless content
  .property 'content'

  defaultTemplate: Ember.Handlebars.compile [
    '<span class="emberella-tag-item-content">{{view.content}}</span>'
    '{{#if view.deleteCharacter}}'
      '<a href="#" {{bindAttr title="view.deleteTitle"}} {{action "removeSelf" target=view bubbles=false}}>{{view.deleteCharacter}}</a>'
    '{{/if}}'
  ].join(' ')

  removeSelf: ->
    parentView = get(@, 'parentView')
    value = get @, 'content'
    parentView.removeValue value
    @

  backspacePressed: (e, alt, ctrl, meta, shift) ->
    return if alt or ctrl or meta or shift
    get(@, 'parentView').cursorAfter @
    @removeSelf()

  deletePressed: Ember.aliasMethod 'backspacePressed'

  rightArrowPressed: (e, alt, ctrl, meta, shift) ->
    return if alt or ctrl or meta
    parentView = get(@, 'parentView')
    if shift
      parentView.focusAfter @
    else
      parentView.cursorAfter @

  leftArrowPressed: (e, alt, ctrl, meta, shift) ->
    return if alt or ctrl or meta
    parentView = get(@, 'parentView')
    if shift
      parentView.focusBefore @
    else
      parentView.moveCursor(@, 0)

  enterPressed: Ember.aliasMethod 'rightArrowPressed'
  tabPressed: Ember.aliasMethod 'rightArrowPressed'

  keyPress: (e) ->
    @_super(e)
    return if e.isDefaultPrevented()
    alt = e.altKey
    ctrl = e.ctrlKey
    meta = e.metaKey
    shift = e.shiftKey
    code = e.keyCode
    parentView = get(@, 'parentView')
    return if meta or ctrl
    parentView.cursorAfter @
    @removeSelf()

Emberella.TagItemInput = Emberella.FlexibleTextField.extend Emberella.FocusableMixin, Emberella.KeyboardControlMixin,
  placeholderBinding: 'parentView.placeholder'
  _delimiter_patternBinding: 'parentView._delimiter_pattern'

  _captureValue: (value) ->
    return false unless value?

    parentView = get(@, 'parentView')
    return false unless parentView?
    value = jQuery.trim(value)

    return false if parentView.contains value

    parentView.addValue value

    return false unless parentView.contains value

    true

  captureValue: (value = get(@, 'value'), retainFocus = true) ->
    parentView = get(@, 'parentView')
    delimiter = get @, '_delimiter_pattern'
    values = value.split delimiter
    captured = false

    parentView?.beginPropertyChanges()

    for v in values
      captured = true if @_captureValue(v)

    if captured
      @reset()
      parentView?.cursorAfter(@) if retainFocus

    parentView?.endPropertyChanges()
    captured

  reset: ->
    set @, 'value', ''
    @

  focus: (e, beginning = false) ->
    return @ unless get(@, 'state') is 'inDOM'
    element = get(@, 'element')
    element?.focus()
    selection = if beginning then 0 else get(@, 'value.length')
    element.selectionStart = selection
    element.selectionEnd = selection
    @adjustWidth()
    @

  isSelectionAtStart: ->
    return false if get(@, 'state') isnt 'inDOM'
    element = get(@, 'element')
    !!(element.selectionStart is 0 and element.selectionEnd is 0)

  isSelectionAtEnd: ->
    return false if get(@, 'state') isnt 'inDOM'
    element = get(@, 'element')
    len = get(@, 'value.length')
    !!(element.selectionStart is len and element.selectionEnd is len)

  enterPressed: (e, alt, ctrl, meta, shift) ->
    return if alt or ctrl or meta or shift
    e.preventDefault()
    @captureValue()

  backspacePressed: (e, alt, ctrl, meta, shift) ->
    return if alt or ctrl or meta or shift
    value = get @, 'value'
    return unless @isSelectionAtStart()
    e.preventDefault()
    parentView = get(@, 'parentView')
    parentView.focusBefore(@) if get(parentView, 'cursor')

  deletePressed: (e, alt, ctrl, meta, shift) ->
    return if alt or ctrl or meta or shift
    value = get @, 'value'
    return unless @isSelectionAtEnd()
    e.preventDefault()
    parentView = get(@, 'parentView')
    parentView.focusAfter @

  rightArrowPressed: (e, alt, ctrl, meta, shift) ->
    return if alt or ctrl or meta
    return unless @isSelectionAtEnd()
    e.preventDefault()
    parentView = get(@, 'parentView')

    if shift
      parentView.focusAfter @
    else
      parentView.cursorAfter(@) unless @captureValue()

  leftArrowPressed: (e, alt, ctrl, meta, shift) ->
    return if alt or ctrl or meta
    return unless @isSelectionAtStart()
    e.preventDefault()
    parentView = get(@, 'parentView')
    if shift
      parentView.focusBefore @
    else
      parentView.cursorBefore(@)

  didValueChange: Ember.observer ->
    value = get(@, 'value')
    delimiter = get @, '_delimiter_pattern'
    regexString = delimiter.toString().split('/').slice(1, -1).join('/')
    regexString = ['.+(', regexString, ')$'].join('')
    pattern = new RegExp(regexString, 'g')

    @captureValue(value) if delimiter.test(value) and (pattern.test(value) or @_didPaste)
    @_didPaste = false
  , 'value'

  paste: (e) -> @_didPaste = true

Emberella.TagsInput = Ember.ContainerView.extend Ember.StyleBindingsMixin, Emberella.FocusableMixin, Emberella.KeyboardControlMixin,

  isTagsInput: true

  classNames: ['emberella-tags-input']
  styleBindings: ['width', 'height']

  itemViewClass: Emberella.TagItemView
  inputViewClass: Emberella.TagItemInput

  _value: null
  _cursor: null

  content: null

  delimiter: null

  tabindex: -1

  width: 'auto'
  height: 'auto'

  placeholder: ''

  deleteCharacter: 'x'
  deleteTitle: "Remove tag"

  _primary_delimiter: Ember.computed ->
    delimiter = get(@, 'delimiter') ? DEFAULT_DELIMITER
    get(delimiter, '0')
    if typeOf delimiter is 'string' then delimiter else DEFAULT_DELIMITER
  .property('delimiter', 'delimiter.length').volatile().readOnly()

  _delimiter_pattern: Ember.computed ->
    delimiter = get(@, 'delimiter') ? DEFAULT_DELIMITER

    if Ember.isArray(delimiter)
      delimiter = Ember.A(delimiter.slice())
      delimiter = delimiter.filter((item) ->
        typeof item is 'string'
      )
      delimiter = Ember.A(DEFAULT_DELIMITER) if delimiter.length is 0
    else if typeOf delimiter is 'string' or typeOf delimiter is 'number'
      delimiter = (delimiter + '').split('')
    else
      delimiter = Ember.A(DEFAULT_DELIMITER)

    patterns = delimiter.map((item) ->
      '\\' + item.split('').join('\\')
    )

    new RegExp(patterns.join('|'), 'g')
  .property('delimiter', 'delimiter.length').volatile().readOnly()

  value: Ember.computed (key, value) ->
    delimiter = get(@, '_primary_delimiter')
    #getter
    if arguments.length is 1
      content = get @, 'content'
      return if (content and content.join) then content.join(delimiter) else get(@, '_value')

    #setter
    else
      set(@, '_value', value)

      result = @_splitStringByDelimiter(value, get(@, 'content'))

      set @, 'content', result
      return @
  .property('content.length', 'content').volatile()

  cursor: Ember.computed (key, value) ->
    delimiter = get(@, 'delimiter')
    #getter
    if arguments.length is 1
      result = get(@, '_cursor')
      contentLength = get(@, 'content.length')
      return contentLength unless result?
      result = Math.max(0, Math.min(parseInt(result, 10), contentLength))
      return result

    #setter
    else
      set(@, '_cursor', value)
  .property('_cursor').volatile()

  init: ->
    ret = @_super()
    content = get(@, 'content')

    if Ember.isArray content
      @_contentDidChange()
    else
      set(@, 'content', Ember.A())

    @_delimiterDidChange()
    @_renderList()
    ret

  contains: (value) ->
    value = jQuery.trim(value + '')
    content = get(@, 'content')
    return false unless content?
    content.contains value

  addValue: (value, idx = get(@, 'cursor')) ->
    return @ unless value?
    value = jQuery.trim(value + '')
    return @ if value is '' or @contains(value)
    get(@, 'content').insertAt idx, value
    set(@, 'cursor', idx + 1)
    @didAddValue value
    @

  removeValue: (value) ->
    return @ unless value?

    content = get(@, 'content')
    idx = content.indexOf value

    return @ if idx < 0

    content.removeObject value
    set(@, 'cursor', idx)
    @didRemoveValue value

  isItemView: (view) ->
    itemViewClass = get @, 'itemViewClass'
    itemViewClass = get(itemViewClass) if typeof itemViewClass is 'string'
    !!(view instanceof itemViewClass)

  isInputView: (view) ->
    inputViewClass = get @, 'inputViewClass'
    inputViewClass = get(inputViewClass) if typeof inputViewClass is 'string'
    !!(view instanceof inputViewClass)

  focusOn: (idx) ->
    childViews = get(@, 'childViews')
    viewToFocus = childViews.objectAt idx
    viewToFocus = get(childViews, 'lastObject') unless viewToFocus?
    @moveFocus viewToFocus, 0

  focusBefore: (view) ->
    @moveFocus view, -1

  focusAfter: (view) ->
    @moveFocus view

  moveFocus: (view, shift = 1) ->
    return @ unless view?
    childViews = get(@, 'childViews')
    idx = childViews.indexOf view

    firstView = get(childViews, 'firstObject')
    lastView = get(childViews, 'lastObject')

    viewToFocus = childViews.objectAt(Math.max(0, Math.min(childViews.length - 1, idx + shift)))
    viewToFocus = lastView unless viewToFocus?

    if @isInputView viewToFocus
      if viewToFocus is firstView
        viewToFocus = childViews.objectAt(1) ? viewToFocus
      else if viewToFocus is lastView
        viewToFocus = childViews.objectAt(childViews.length - 1) ? viewToFocus
      else
        idx = childViews.indexOf viewToFocus
        viewToFocus = childViews.objectAt(idx + (shift/Math.abs(shift)))

    get(viewToFocus, 'element').focus()
    @

  cursorBefore: (view) ->
    @moveCursor view, -1

  cursorAfter: (view) ->
    @moveCursor view

  moveCursor: (view, shift = 1) ->
    return @ unless view?
    cursor = get(@, 'cursor')
    childViews = get(@, 'childViews')
    idx = childViews.indexOf view
    shift = shift - 1 if idx > cursor
    set(@, 'cursor', idx + shift)
    @_focusOnInputView(true, (shift >= 0))
    @

  didAddValue: Ember.K
  didRemoveValue: Ember.K

  click: (e) ->
    return unless e.target is get(@, 'element')
    posX = e.pageX
    posY = e.pageY
    nearest = @.find((childView) ->
      jQ = childView.$()
      position = jQ.offset()
      height = jQ.outerHeight(true)
      space = jQ.outerWidth(true) - jQ.width()
      !!((position.left > (posX - space) and (position.top + height) > posY) or position.top > posY)
    )
    idx = @indexOf(nearest)
    idx = idx - 1 if idx > get(@, 'cursor')
    set(@, 'cursor', if nearest then idx else get(@, 'content.length'))
    @_focusOnInputView(true)

  _cursorDidChange: Ember.observer ->
    @_updateChildViews()
  , 'cursor'

  _delimiterDidChange: Ember.observer ->
    content = get(@, 'content')
    _value = content.join(get(@, '_primary_delimiter'))
    set(@, 'content', @_splitStringByDelimiter(_value, content))
  , 'delimiter'

  _focusDidChange: Ember.observer ->
    set @, 'hasFocus', @_hasFocus()
  , '@each.hasFocus'

  _hasFocusDidChange: Ember.observer ->
    unless get(@, 'hasFocus')
      Ember.run.later @, ->
        return unless get(@, 'state') is 'inDOM' and !@_hasFocus()
        inputView = get(@, 'inputView')
        inputView.captureValue(null, false) if inputView? and inputView.captureValue
        set @, 'cursor', get(@, 'childViews.length')
      , 100
  , 'hasFocus'

  ###
    Hook for responding to the content array being replaced with a new
    array instance. Override to add custom handling.

    @method contentWillChange
    @param {Object} self
  ###
  contentWillChange: Ember.K

  ###
    Hook for responding to the content array being replaced with a new
    array instance. Override to add custom handling.

    @method contentDidChange
    @param {Object} self
  ###
  contentDidChange: ->
    @_rerenderList() if get(@, 'state') is 'inDOM'

  ###
    Hook for responding to impending updates to the content array. Override to
    add custom handling for array updates.

    @method contentArrayWillChange
    @param {Array} array The array instance being updated
    @param {Integer} idx The index where changes applied
    @param {Integer} removedCount
    @param {Integer} addedCount
  ###
  contentArrayWillChange: (array, idx, removedCount, addedCount) ->
    @

  ###
    Hook for responding to updates to the content array. Override to
    add custom handling for array updates.

    @method contentArrayDidChange
    @param {Array} array The array instance being updated
    @param {Integer} idx The index where changes applied
    @param {Integer} removedCount
    @param {Integer} addedCount
  ###
  contentArrayDidChange: (array, idx, removedCount, addedCount) ->
    @_updateChildViews()
    @

  ###
    @private

    Content array change handler.

    @method _contentWillChange
  ###
  _contentWillChange: Ember.beforeObserver ->
    content = get(@, 'content')
    len = if content then get(content, 'length') else 0

    @contentArrayWillChange @, 0, len, undefined
    @contentWillChange @
    @_teardownContent content
  , 'content'

  ###
    @private

    Content array change handler.

    @method _contentDidChange
  ###
  _contentDidChange: Ember.observer ->
    content = get(@, 'content')
    len = if content then get(content, 'length') else 0

    @_setupContent content
    @contentDidChange @
    @contentArrayDidChange @, 0, undefined, len
  , 'content'

  ###
    @private

    Remove change observing on content array.

    @method _teardownContent
  ###
  _teardownContent: ->
    @_clearContent()
    content = get(@, 'content')
    if content
      content.removeArrayObserver @,
        willChange: 'contentArrayWillChange',
        didChange: 'contentArrayDidChange'

  ###
    @private

    Begin change observing on content array.

    @method _setupContent
  ###
  _setupContent: ->
    content = get(@, 'content')
    if content
      content.addArrayObserver @,
        willChange: 'contentArrayWillChange',
        didChange: 'contentArrayDidChange'

  ###
    @private

    Empty the content array.

    @method _clearContent
  ###
  _clearContent: ->
    content = get(@, 'content')
    content.clear() if content

  _renderList: ->
    Ember.run.schedule 'afterRender', @, ->
      @_updateChildViews()

  _rerenderList: ->
    @destroyAllChildren()
    @_renderList()

  _hasFocus: ->
    focused = @find((childView) ->
      get(childView, 'hasFocus')
    )
    return !!(focused)

  _focusOnInputView: (force, beginning) ->
    inputView = get(@, 'inputView')

    return unless force or @_hasFocus()

    if get(inputView, 'state') is 'inDOM'
      inputView.focus({}, beginning)
    else
      Ember.run.schedule 'afterRender', @, ->
        inputView.focus({}, beginning) if force or @_hasFocus()

  _insertInputView: ->
    inputView = get(@, 'inputView')
    inputView = if inputView and !get(inputView, 'isDestroyed') and !get(inputView, 'isDestroying') then inputView else @_createInputView()
    cursor = get @, 'cursor'
    @insertAt(cursor, inputView)
    null

  _removeInputView: ->
    inputView = get(@, 'inputView')
    inputView = if inputView and !get(inputView, 'isDestroyed') and !get(inputView, 'isDestroying') then inputView else @_createInputView()
    inputView.removeFromParent()
    null

  _createInputView: ->
    inputViewClass = get @, 'inputViewClass'
    inputViewClass = get(inputViewClass) if typeof inputViewClass is 'string'
    inputView = @createChildView(inputViewClass)
    set @, 'inputView', inputView
    inputView

  _updateChildViews: ->
    return if get(@, 'isDestroyed')
    @_removeInputView()

    childViews = @
    childViewsLength = Math.max(0, get(@, 'length'))

    itemViewClass = get @, 'itemViewClass'
    itemViewClass = get(itemViewClass) if typeof itemViewClass is 'string'

    content = get(@, 'content')
    contentLength = get(@, 'content.length')

    for i in [0...Math.max(childViewsLength, contentLength)]
      childView = @objectAt(i)

      if i < contentLength
        unless childView instanceof itemViewClass
          childView = @createChildView(itemViewClass)
          @insertAt(i, childView)
        set childView, 'content', content[i]
      else
        childView?.removeFromParent() if childView instanceof itemViewClass

    @_insertInputView()
    null

  _splitStringByDelimiter: (str = '', result = Ember.A()) ->
    pattern = get(@, '_delimiter_pattern')
    values = str.split(pattern)
    result.clear()

    for v in values
      v = jQuery.trim v
      continue if !v? or v is ''
      result.addObject v

    result
