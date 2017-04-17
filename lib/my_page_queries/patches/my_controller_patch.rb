require_dependency 'query'
require_dependency 'issue_query' if Redmine::VERSION.to_s >= '2.3.0'

module MyPageQueries::Patches::MyControllerPatch
  extend ActiveSupport::Concern

  included do

    before_filter :apply_default_layout, :only => [:add_block, :remove_block],
                  :if => proc { User.current.pref[:my_page_layout].nil? }

    before_filter :my_page_sort_init

    alias_method_chain :add_block, :query_and_text

    helper :sort
    include SortHelper
    helper :queries
    include QueriesHelper

    helper :my_page_queries
    include MyPageQueriesHelper

    helper_method :per_page_option
  end

  def default_layout
    @user = User.current
    # remove block in all groups
    @user.pref[:my_page_layout] = nil
    @user.pref.save
    redirect_to :action => 'page_layout'
  end

  def add_block_with_query_and_text(user = User.current)
    if (block = detect_query_block_from_params)
      add_block_to_top(user, block)
      redirect_to :action => 'page_layout'
    elsif (block = detect_new_text_block_from_params)
      user.update_my_page_text_block(block, l(:label_text)) if user.my_page_text_block(block).blank?
      add_block_to_top(user, block)
      redirect_to :action => 'page_layout'
    else
      add_block_without_query_and_text
    end
  end

  def update_query_block
    @user = User.current
    query = @user.detect_query params[:query_id]
    if query
      @block_name = "query_#{query.id}"
      update_user_query_pref_from_param(@user)
      render 'query_block', :layout => false
    else
      render_404
    end
  end

  def update_text_block
    @user = User.current
    text = params[:my_page_text_area]
    block_name = params[:block_name]
    @user.update_my_page_text_block(block_name, text)
    render 'update_text',
           :layout => false,
           :content_type => 'text/javascript',
           :locals => {
               :block_name => block_name,
               :text => text
           }
  end

  private

  def apply_default_layout
    user = User.current
    # make a deep copy of default layout
    user.pref[:my_page_layout] = Marshal.load(Marshal.dump(MyController::DEFAULT_LAYOUT))
    user.save
  end

  def my_page_sort_init
    sort_init('none')
    sort_update(['none'])
  end

  def add_block_to_top(user, block)
    layout = user.pref[:my_page_layout] || {}
    # remove if already present in a group
    %w(top left right).each {|f| (layout[f] ||= []).delete block }
    # add it on top
    layout['top'].unshift block
    user.pref[:my_page_layout] = layout
    user.pref.save
  end

  def detect_query_block_from_params
    block = params[:block].to_s.underscore
    block if extract_query_id_from_block(block)
  end

  def detect_new_text_block_from_params(user = User.current)
    block = params[:block].to_s.underscore
    return nil unless block == MyPageQueries::TEXT_BLOCK
    layout = user.pref[:my_page_layout] || {}
    block_id = 1
    while true
      block = "#{MyPageQueries::TEXT_BLOCK}_#{block_id}"
      return block unless %w(top left right).detect { |f| (layout[f] ||= []).include?(block) }
      block_id += 1
    end
  end

  def update_user_query_pref_from_param(user)
    return unless params[:query]
    query_key = "query_#{params[:query_id]}".to_sym
    opts = user.pref[query_key] || {}
    opts.merge! params[:query].symbolize_keys
    user.pref[query_key] = opts
    user.pref.save!
  end
end

unless MyController.included_modules.include?(MyPageQueries::Patches::MyControllerPatch)
  MyController.send :include, MyPageQueries::Patches::MyControllerPatch
end
