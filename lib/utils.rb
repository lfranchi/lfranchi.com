module SiteUtils

    def write_tag_page(dir, tag, count)
        meta = {}
        meta[:title] = "Tag: #{tag}"
        meta[:type] = 'page'
        meta[:feed] = "/tags/#{tag}/"
        meta[:feed_title] = "Tag '#{tag}'"
        meta[:permalink] = tag
        pl = (count == 1) ? ' is' : 's are'
        contents = %{
%p 
    #{count} item#{pl} tagged with <em>#{tag}</em>:
%ul
    - articles_tagged_with('#{tag}').each do |a| 
        = render 'dated_article', :article => a
    }
        # Write html page
        write_item dir/"#{tag}.haml", meta, contents
    end

    def write_tag_feed_page(dir, tag, format)
        f = format.downcase
        meta = {}
        meta[:title] = "lfranchi.com - Tag '#{tag}' (#{format} Feed)" 
        meta[:kind] = 'feed'
        meta[:permalink] = "tags/#{tag}/#{f}"
        contents = %{= atom_feed(:articles => articles_tagged_with('clojure'))}
        write_item dir/"#{tag}-#{f}.xml.haml", meta, contents
    end

    def write_archive_page(dir, name, count)
        meta = {}
        meta[:title] = "Archive: #{name}"
        meta[:kind] = 'page'
        meta[:permalink] = name.downcase.gsub /\s/, '-'
        pl = (count == 1) ? ' was' : 's were'
        contents = %{
%p
    #{count} article#{pl} written in <em>#{name}</em>
%ul
    - articles_by_month.select\{ |i| i[0] == "#{name}"\}[0][1].each do |a|
        = render 'dated_article', :article => a
    }
        # Write file
        write_item dir/"#{meta[:permalink]}.haml", meta, contents
    end

    def write_item(path, meta, contents)
        path.parent.mkpath
        (path).open('w+') do |f|
            f.print "--"
            f.puts meta.to_yaml
            f.puts "-----"
            f.puts contents
        end 
    end

end
