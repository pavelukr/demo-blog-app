# frozen_string_literal: true
require 'csv'

class ActiveImportCommentsService
  def call
    users_data = []
    post_slugs = []
    comments_data = []
    non_valid_comments = []
    comments_to_delete = []
    CSV.foreach('comments.csv', headers: true) do |row|
      comment_data = { post_slug: row['Post Slug'], email: row['User Email'], content: row['Content'] }
      prohibited_keywords = check_for_prohibited_keywords(comment_data)
      if prohibited_keywords.present?
        non_valid_comments << "#{comment_data}, error: #{prohibited_keywords}"
      else
        post_slugs << row['Post Slug']
        users_data << { name: row['User Name'], email: row['User Email'] }
        comments_data << comment_data
      end
    end

    post_data = Post.where(slug: post_slugs.uniq!).select(:id, :slug)
                    .group_by(&:slug).transform_values { |arr| arr.first.id }
    present_users = User.where(email: users_data.map { |u| u[:email] }).select(:id, :email, :name)
    users_to_import = users_data - present_users.map { |u| { name: u.name, email: u.email } }
    User.insert_all(users_to_import) if users_to_import.any?
    users = (present_users.select(:id, :email) + User.where(email: users_to_import.map { |u| u[:email] }).select(:id, :email)).group_by(&:email).transform_values { |arr| arr.first.id }
    comments_data.each_with_index do |comment|
      comment[:post_id] = post_data[comment[:post_slug]]
      comment[:user_id] = users[comment[:email]]
      comment.delete(:post_slug)
      comment.delete(:email)
      comment_errors = comment_errors(comment)
      next if comment_errors.blank?

      non_valid_comments << "#{comment}, error: #{comment_errors}"
      comments_to_delete << comment
    end

    comments_to_import = comments_data - comments_to_delete
    Comment.insert_all(comments_to_import) if comments_to_import.any?
    non_valid_comments
  end

  private

  def comment_errors(comment)
    return 'User should be present' unless comment[:user_id].present?

    'Post should be present' unless comment[:post_id].present?
  end

  def check_for_prohibited_keywords(comment_data)
    prohibited_keywords = 20.times.map { Faker::Lorem.unique.word }
    prohibited_keywords.each do |keyword|
      if comment_data[:content].downcase.include?(keyword)
        return 'Contains prohibited words: ' + keyword
      end
    end
  end
end
