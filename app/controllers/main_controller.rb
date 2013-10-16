class MainController < ApplicationController
  def home
  end

  def dependencies
    gems = params[:gems].to_s
      .split(",")
      .select {|e| e.start_with?(GEM_PREFIX) }
      .flat_map do |name|

      component_name = name.gsub(GEM_PREFIX, "")
      component = Component.where(name: component_name).first

      if component.blank? || component.versions.built.count == 0
        build(component_name)
        Reindex.new.perform
      end

      if component
        component.versions.built.map do |v|
          {
            name:         name,
            platform:     "ruby",
            number:       v.string,
            dependencies: v.dependencies.to_a.map {|n,v| ["#{GEM_PREFIX}#{n}", v] }
          }
        end
      else
        []
      end
    end

    params[:json] ? render(json: gems) : render(text: Marshal.dump(gems))
  end

  protected

  def build(name)
    Build::Convert.new(name).try_convert(debug: params[:_debug]).try(:[], :component)
  end
end
