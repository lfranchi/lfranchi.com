include Nanoc::Helpers::Tagging
include Nanoc::Helpers::Rendering
include Nanoc3::Helpers::Blogging
include Nanoc3::Helpers::LinkTo

module Nanoc::Helpers::Tagging

    def site_tags
        ts = {}
        @items.each do |p|
            next unless p[:tags]
            p[:tags].each do |t|
                if ts[t]
                    ts[t] = ts[t]+1
                else
                    ts[t] = 1 
                end
            end
        end
        ts
    end

    def tags_for(article)
        article.attributes[:tags].map{|t| %{<a class="tag" href="/tags/#{t}/">#{t}</a>}}.join
    end

    def link_for_tag(tag, base_url)
        %[<a href="#{base_url}#{tag.downcase}/" rel="tag">#{tag}</a>]
    end

    def tag_link_with_count(tag, count)
        %{#{link_for_tag(tag, '/tags/')} (#{count})}
    end 

    def sorted_site_tags
        site_tags.sort{|a, b| a[0] <=> b[0]}
    end

    def articles_tagged_with(tag)
        @site.items.select{|p| p.attributes[:tags] && p.attributes[:tags].include?(tag)}.sort{|a,b| a.attributes[:created_at] <=> b.attributes[:created_at]}.reverse
    end

    def latest_articles(max=nil)
        total = @site.items.select{|p| p.attributes[:kind] == 'article'}.sort{|a, b| a.attributes[:created_at] <=> b.attributes[:created_at]}.reverse 
        max ||= total.length
        total[0..max-1]
    end

    def articles_by_month
        articles = latest_articles
        m_articles = []
        index = -1
        current_month = ""
        articles.each do |a|
            next unless a.attributes[:created_at]
            month = a.attributes[:created_at].strftime("%B %Y")
            if current_month != month then
                # new month
                m_articles << [month, [a]]
                index = index + 1
                current_month = month
            else
                # same month
                m_articles[index][1] << a
            end
        end
        m_articles
    end
end
