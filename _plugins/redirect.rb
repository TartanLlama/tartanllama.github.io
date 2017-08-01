module Jekyll

  # The redirect page creates a simple page that refreshes a user from a URL alias to an existing post.
  # Redirects are only generated if there is a "redirects" parameter _config.yml

  class Redirects < Generator

    safe true
    priority :low

    # only process redirects if it's set in the config file
    def generate(site)
      generate_redirects(site) if (site.config['redirects'])
    end

    # find all posts with a redirect property and create a new page for each entry
    def generate_redirects(site)
      site.posts.docs.select{|x| x.data['layout'] == 'post' }.each do |p|
        # Only for old posts to keep links alive
        if p.data['date'] <= Time.parse("2017-08-01")
          date = p.data['date'].strftime("%Y/%m/%d")
          url = "#{p.data['category']}/#{date}/#{p.data['slug']}"
          redirect = RedirectPage.new(site, site.source, url, p.id)
          redirect.render(site.layouts, site.site_payload)
          redirect.write(site.dest)
          site.pages << redirect
        end
      end
    end
  end

  # a class for generating the redirect pages.
  class RedirectPage < Page

    def initialize(site, base, path, destination)

      @site = site
      @base = base
      @dir  = path
      @name = 'index.html'
      self.process(@name)

      # Read the YAML data from the layout page.
      self.read_yaml(File.join(base, '_layouts'), 'redirect.html')
      self.data['source_url'] = destination

    end

  end

end
