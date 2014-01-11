app = angular.module("app", [])

app.filter 'semverSort', ->
  (items) ->
    filtered = []
    angular.forEach items, (item) ->
      filtered.push(item)
    filtered.sort (a, b) ->
      semver.gt(a, b)
    filtered

app.directive "ngHtml", ->
  (scope, element, attrs) ->
    scope.$watch attrs.ngHtml, (value) ->
      element[0].innerHTML = value


app.directive "dependencies", ->
  (scope, element, attrs) ->
    scope.$watch attrs.dependencies, (deps) ->
      html = []

      for dep in deps
        h = "<span class=\"name\">" + dep[0] + "</span>"
        h += "<span class=\"req\"> (" + dep[1] + ")</span>"
        html.push h

      element[0].innerHTML = html.join(", ")


app.controller "IndexCtrl", ["$scope", "$http", ($scope, $http) ->
  $scope.fetch = ->
    $http.get("/components.json").then (res) ->
      $scope.gems = res.data

      if $scope.gems.length == 1
        $scope.$broadcast 'showAssets'

  $scope.fetch()

  $scope.search =
    name: ""

  $scope.$watch 'search.name', (name) ->
    $scope.$broadcast('component.name', name)
]

app.controller 'GemCtrl', ['$scope', '$http', ($scope, $http) ->
  $scope.javascripts = []
  $scope.stylesheets = []
  $scope.jsManifest = false
  $scope.cssManifest = false

  $scope.fetchAssets = (version) ->
    $http.get("/components/#{$scope.gem.name}/#{version}").then (response) ->
      $scope.javascripts = (path for path in response.data when path.type is 'javascript')
      $scope.stylesheets = (path for path in response.data when path.type is 'stylesheet')
      $scope.jsManifest = (path for path in $scope.javascripts when path.main is true).length > 0
      $scope.cssManifest = (path for path in $scope.stylesheets when path.main is true).length > 0
]

app.controller "ConvertCtrl", ["$scope", "$http", ($scope, $http) ->
  $scope.converting = false
  $scope.component =
    name: null
    version: null

  $scope.error = null

  $scope.$on 'component.name', (event, name) ->
    $scope.component.name = name

  $scope.convert = ->
    $scope.converting = true
    $scope.error = null
    $scope.gem = null

    $http.post("/components.json", component: $scope.component).success((data, xhr) ->
      $scope.gem = data
      $scope.converting = false
    ).error (data, status) ->
      $scope.converting = false
      if status == 302
        $scope.error =
          message: "Package #{component} already exist"
      else
        console.log(data)
        if data?
          $scope.error = data
        else
          $scope.error = "There was an critical error. It was reported to our administrator."
]
