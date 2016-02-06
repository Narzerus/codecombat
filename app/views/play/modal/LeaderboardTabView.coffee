CocoView = require 'views/core/CocoView'
CocoClass = require 'core/CocoClass'
template = require 'templates/play/modal/leaderboard-tab-view'
CocoCollection = require 'collections/CocoCollection'
LevelSession = require 'models/LevelSession'

class TopScoresCollection extends CocoCollection
  url: ''
  model: LevelSession

  constructor: (@level, @scoreType, @timespan) ->
    super()
    @url = "/db/level/#{@level.get('original')}/top_scores/#{@scoreType}/#{@timespan}"

class LeaderboardData extends CocoClass
  constructor: (@level, @scoreType, @timespan) ->
    super()

  fetch: ->
    mySession = new LevelSession().setURL "/db/level/#{@level.id}/session"
    topScores = new TopScoresCollection @level, @scoreType, @timespan
    aboveScores = new TopScoresCollection @level, @scoreType, @timespan
    belowScores = new TopScoresCollection @level, @scoreType, @timespan

    gettingTopScores = topScores.fetch({data: {limit: 3}}).then =>
      @topScores = topScores
    gettingAdjacentScores = mySession.fetch().then () =>
      myTopScore = _.max mySession.get('state').topScores, (topScore) ->
        topScore.score

      gettingAboveScores = aboveScores.fetch
        data:
          limit: 2
          scoreOffSet: myTopScore.score
          order: -1
      gettingBelowScores = belowScores.fetch
        data:
          limit: 2
          scoreOffSet: myTopScore.score
          order: 1

      # TODO: These can be set pre-fetch as the object is updated on sync
      gettingAboveScores.then =>
        @aboveScores = belowScores
      gettingBelowScores.then =>
        @belowScores = belowScores

      $.when [gettingAboveScores, gettingBelowScores]

    @gettingData = $.when [gettingTopScores, gettingAdjacentScores]

    @gettingData.then @onLoad
    @gettingData.fail @onFail

  onLoad: =>
    return if @destroyed
    @loaded = true
    @trigger 'sync', @

  onFail: (resource, jqxhr) =>
    return if @destroyed
    @trigger 'error', @, jqxhr

  loaded = false

module.exports = class LeaderboardTabView extends CocoView
  template: template
  className: 'leaderboard-tab-view'

  events:
    'click tbody tr.viewable': 'onClickRow'

  constructor: (options) ->
    super options
    @level = @options.level
    @scoreType = @options.scoreType ? 'time'
    @timespan = @options.timespan

  destroy: ->
    super()

  getRenderData: ->
    # FIXME: Here `@leaderboardData` out of a sudden gets undefined
    c = super()
    c.scoreType = @scoreType
    c.timespan = @timespan
    c.topScores = @formatTopScores @leaderboardData?.topScores
    c.aboveScores = @formatTopScores @leaderboardData?.aboveScores
    c.belowScores = @formatTopScores @leaderboardData?.belowScores
    c.loading = not @leaderboardData or not @leaderboardData.loaded
    c._ = _
    c

  afterRender: ->
    super()

  formatTopScores: (sessions) ->
    return [] unless sessions?.models
    rows = []
    for s in sessions.models
      row = {}
      score = _.find s.get('state').topScores, type: @scoreType
      row.ago = moment(new Date(score.date)).fromNow()
      row.score = @formatScore score
      row.creatorName = s.get 'creatorName'
      row.creator = s.get 'creator'
      row.session = s.id
      row.codeLanguage = s.get 'codeLanguage'
      row.hero = s.get('heroConfig')?.thangType
      row.inventory = s.get('heroConfig')?.inventory
      rows.push row
    rows

  formatScore: (score) ->
    switch score.type
      when 'time' then -score.score.toFixed(2) + 's'
      when 'damage-taken' then -Math.round score.score
      when 'damage-dealt', 'gold-collected', 'difficulty' then Math.round score.score
      else score.score

  onShown: ->
    return if @hasShown
    @hasShown = true

    @leaderboardData = new LeaderboardData @level, @scoreType, @timespan
    @leaderboardDataResource = @supermodel.addModelResource @leaderboardData, {cache: false}
    @leaderboardDataResource.load()

  onClickRow: (e) ->
    sessionID = $(e.target).closest('tr').data 'session-id'
    url = "/play/level/#{@level.get('slug')}?session=#{sessionID}&observing=true"
    window.open url, '_blank'
