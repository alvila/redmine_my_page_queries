require_dependency 'project'
require_dependency 'principal'
require_dependency 'user'

module MyPageQueries::Patches::UserPatch
  extend ActiveSupport::Concern

  def detect_query(query_id)
    visible_queries.detect { |q| q.id == query_id.to_i }
  end

  def visible_queries
    @visible_queries ||= my_visible_queries.to_a + other_visible_queries.to_a
  end

  def my_visible_queries
    visible_queries_scope.where('queries.user_id = ?', self.id).order('queries.name')
  end

  def other_visible_queries
    visible_queries_scope.where('queries.user_id <> ?', self.id).order('queries.name')
  end

  def queries_from_my_projects
    @queries_from_my_projects ||= other_visible_queries.find_all do |q|
      q.is_public? && q.project && member_of?(q.project)
    end
  end

  def queries_from_public_projects
    @queries_from_public_projects ||= other_visible_queries.to_a - queries_from_my_projects
  end

  def visible_queries_scope
    kl = defined?(IssueQuery) ? IssueQuery : Query
    kl.visible(self)
  end

  def update_my_page_text_block(block_name, val)
    pref[:my_page_text_blocks] ||= {}
    pref[:my_page_text_blocks][block_name] = val
    pref.save
  end

  def my_page_text_block(block_name)
    pref[:my_page_text_blocks] && pref[:my_page_text_blocks][block_name]
  end
end

unless User.included_modules.include?(MyPageQueries::Patches::UserPatch)
  User.send :include, MyPageQueries::Patches::UserPatch
end
