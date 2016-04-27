class Concept::SKOS::Base < Concept::Base

  belongs_to :ark

  include Rails.application.routes.url_helpers

  self.rdf_namespace = 'skos'
  self.rdf_class = 'Concept'

  def build_rdf_subject(&block)
    ns = IqRdf::Namespace.find_namespace_class(self.rdf_namespace)
    raise "Namespace '#{self.rdf_namespace}' is not defined in IqRdf document." unless ns
    subject = IqRdf.build_uri(self.origin, ns.build_uri(self.rdf_class), &block)

    # ensure skos:Concept type is present
    unless self.rdf_namespace == 'skos' && self.rdf_class == 'Concept'
      subject.Rdf.build_predicate('type', IqRdf::Skos.build_uri('Concept'))
    end

    return subject
  end

  # ********** Scopes
  def self.expired(time = Time.now)
    where(arel_table[:expired_at].lt(time))
  end

  def self.not_expired(time = Time.now)
    col = arel_table[:expired_at]
    where((col.eq(nil)).or(col.gteq(time)))
  end

  after_save do |concept|
    ark_id = concept.inline_match_skos_exact_matches.match(/(ark:\/[0-9a-z\/]+)/).to_s
    if !ark_id.blank?
      @ark = Ark.new()
      @ark.id = ark_id
      @ark.what = concept.to_s
      @ark.save
    elsif concept.rev == 1
      lang = I18n.locale.to_s == 'none' ? nil : I18n.locale.to_s
      w = concept_url(:lang => lang, :id => concept.origin, :format => 'html', :host => Iqvoc.config["site_url"])
      @ark = Ark.create(
        who: Iqvoc.config["minter.erc_who"],
        when: Time.now.strftime("%Y-%m-%d"), 
        what: concept.to_s,
        where: w.to_s
      )
      @url = Iqvoc.config["minter.base_url"] + @ark.id
      concept.send("Match::SKOS::ExactMatch".to_relation_name).create(value: @url)
      #concept.origin = @ark.id.split('/')[2]
    end
  end
end