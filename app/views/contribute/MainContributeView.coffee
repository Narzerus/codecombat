ContributeClassView = require 'views/contribute/ContributeClassView'
template = require 'templates/contribute/contribute'

module.exports = class MainContributeView extends ContributeClassView
  id: 'contribute-view'
  template: template
  navPrefix: ''

  events:
    'change input[type="checkbox"]': 'onCheckboxChanged'
