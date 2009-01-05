# a module to include in your controllers
# params:
# q => search word
# search => {name=>something}
# order => name DESC
# define the constant PER_PAGE in your controller so it can be used here
module Modules
  module HeSearch
    def current_objects
      @current_objects ||= current_model.fulltext_results(params[:q],:page=>params[:page],:per_page=>self.class.const_get('PER_PAGE'),:attributes=>params[:search],:order=>params[:order])
    end
  end
end