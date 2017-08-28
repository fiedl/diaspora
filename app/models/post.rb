#   Copyright (c) 2010-2011, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

class Post < ApplicationRecord
  self.include_root_in_json = false

  include ApplicationHelper

  include Diaspora::Federated::Base

  include Diaspora::Likeable
  include Diaspora::Commentable
  include Diaspora::Shareable
  include Diaspora::MentionsContainer

  has_many :participations, dependent: :delete_all, as: :target, inverse_of: :target
  has_many :participants, through: :participations, source: :author

  attr_accessor :user_like

  has_many :reports, as: :item

  has_many :reshares, class_name: "Reshare", foreign_key: :root_guid, primary_key: :guid
  has_many :resharers, class_name: "Person", through: :reshares, source: :author

  belongs_to :o_embed_cache, optional: true
  belongs_to :open_graph_cache, optional: true

  validates_uniqueness_of :id

  before_create :convert_html_to_markdown

  after_create do
    self.touch(:interacted_at)
  end

  #scopes
  scope :includes_for_a_stream, -> {
    includes(:o_embed_cache,
             :open_graph_cache,
             {:author => :profile},
             :mentions => {:person => :profile}
    ) #note should include root and photos, but i think those are both on status_message
  }

  scope :all_public, -> { where(public: true) }

  scope :commented_by, ->(person)  {
    select('DISTINCT posts.*')
      .joins(:comments)
      .where(:comments => {:author_id => person.id})
  }

  scope :liked_by, ->(person) {
    joins(:likes).where(:likes => {:author_id => person.id})
  }

  scope :subscribed_by, ->(user) {
    joins(:participations).where(participations: {author_id: user.person_id})
  }

  scope :reshares, -> { where(type: "Reshare") }

  scope :reshared_by, ->(person) {
    # we join on the same table, Rails renames "posts" to "reshares_posts" for the right table
    joins(:reshares).where(reshares_posts: {author_id: person.id})
  }

  def post_type
    self.class.name
  end

  def root; end
  def photos; []; end

  #prevents error when trying to access @post.address in a post different than Reshare and StatusMessage types;
  #check PostPresenter
  def address
  end

  def poll
  end

  def self.excluding_blocks(user)
    people = user.blocks.map{|b| b.person_id}
    scope = all

    if people.any?
      scope = scope.where("posts.author_id NOT IN (?)", people)
    end

    scope
  end

  def self.excluding_hidden_shareables(user)
    scope = all
    if user.has_hidden_shareables_of_type?
      scope = scope.where('posts.id NOT IN (?)', user.hidden_shareables["#{self.base_class}"])
    end
    scope
  end

  def self.excluding_hidden_content(user)
    excluding_blocks(user).excluding_hidden_shareables(user)
  end

  def self.for_a_stream(max_time, order, user=nil, ignore_blocks=false)
    scope = self.for_visible_shareable_sql(max_time, order).
      includes_for_a_stream

    if user.present?
      if ignore_blocks
        scope = scope.excluding_hidden_shareables(user)
      else
        scope = scope.excluding_hidden_content(user)
      end
    end

    scope
  end

  def reshare_for(user)
    return unless user
    reshares.where(:author_id => user.person.id).first
  end

  def like_for(user)
    return unless user
    likes.where(:author_id => user.person.id).first
  end

  def convert_html_to_markdown
    # If the text contains html tags and markdown syntax, we need to convert both markdown.
    # Otherwise, there are parsing issues later.
    #
    # I get the best results when converting everything to html first, and then back to markdown.
    #
    if self.text.try(:include?, "</") || self.text.try(:include?, "/>")

      # 1. Convert markdown to html.
      #    https://github.com/vmg/redcarpet
      #
      self.text = Redcarpet::Markdown.new(Redcarpet::Render::HTML, hard_wrap: true).render(self.text)

      # 2. Convert double newlines to paragraphs. Otherwise, these will be lost,
      #    which looks especially bad after images.
      #
      self.text = self.text.gsub("\n\n", "</p><p>")
      self.text = self.text.gsub("\r\n", "</p><p>")

      # 3. Clean up some issues that would cause problems when converting to markdown.
      #
      self.text = self.text.gsub /align=\"[^ ]*\"/, ""      # ReverseMarkdown does not understand this in image tags
      self.text = self.text.gsub /hspace=\"[^ ]*\"/, ""     #
      self.text = self.text.gsub /img[ ]*src=/, "img src="  #
      self.text = self.text.gsub(/(<img[^>]*>)([^\n<])/) { $1 + "</p><p>" + $2 }  # New paragraph after images

      # 4. Convert everything back to markdown.
      #    https://github.com/xijo/reverse_markdown
      #
      self.text = ReverseMarkdown.convert self.text
    end
  end

  def subscriptions
    Subscription.by_post self
  end

  def subscriber_users  # "subscribers" is already taken :(
    subscriptions.map(&:subscriber).uniq
  end

  #############

  # @return [Integer]
  def update_reshares_counter
    self.class.where(id: id).update_all(reshares_count: reshares.count)
  end

  def self.diaspora_initialize(params)
    new(params.to_hash.stringify_keys.slice(*column_names, "author"))
  end

  def comment_email_subject
    I18n.t('notifier.a_post_you_shared')
  end

  def nsfw
    self.author.profile.nsfw?
  end

  def subscribers
    super.tap do |subscribers|
      subscribers.concat(resharers).concat(participants) if public?
    end
  end
end
