# frozen_string_literal: true
require 'csv'

class ImportCommentsService
  def call
    failed_comments = []
    CSV.foreach('comments.csv', headers: true) do |row|
      post = Post.find_by_slug(row['Post Slug'])
      failed_comments << "name: #{row['User Name']}, email: #{row['User Email']}, content: #{row['Content']},
                          errors: The corresponding post was not found in the database." if post.nil?
      next unless post.present?

      ActiveRecord::Base.transaction do
        user_id = User.find_or_create_by(name: row['User Name'], email: row['User Email']).id
        Comment.create!(post_id: post.id, user_id: user_id, content: row['Content'])
      end
    rescue ActiveRecord::RecordInvalid => e
      failed_comments << "post_id: #{e.record&.post_id}, user_id: #{e.record&.user_id}, content: #{e.record&.content}, errors: #{e.message}"
    end
    failed_comments
  end
end
