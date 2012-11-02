#! /usr/bin/env ruby

require 'hpricot'
require 'open-uri'
require 'builder'
require 'iconv'

# A structure to hold information about each bike.
class Bike < Struct.new(:name, :link, :text, :images); end

# Takes in a URI and returns an Hpricot object that's been feed UTF-8 clean text.
def scrape(uri)
  site = open(uri)
  data = ""
  site.each_line { |x| data += x }
  Hpricot(Iconv.conv('utf-8', 'iso-8859-1', data))
end

# Scrape the homepage and cherry-pick links to the first ten bikes.
fgg = scrape('http://fixedgeargallery.com')
links = fgg.search('td[@width=302]').first.search('img[@src="button3.gif"] ~ a[@target="blank"]')[0..9]
bikes = []

# Follow each of the links and build bikes from each link.
links.each do |link|
  
  # Scrape the invdividual bike page and extract some data.
  url = (link[:href][0..3] != 'http') ? 'http://fixedgeargallery.com/' + link[:href] : link[:href]
  puts "Found link to: " + url
  
  begin
    page = scrape(url)
    
    # Remove any JS so the feed validates.
    page.search('script').remove
    page.search('noscript').remove
    
    img_base_url = 'http://fixedgeargallery.com/' + link[:href][0..link[:href].rindex('/')]
    
    # Build each bike from the scraped data.
    bike = Bike.new
    bike.name = link.inner_text
    bike.link = url
    bike.text = page.search('div[@class="p"]').map { |x| x.to_html }.join
    bike.images = page.search('img').map { |image| '<img src="' + img_base_url + image[:src] + '" /><br/>' }.join

    # Add the bike to the list.
    bikes << bike
    
    puts "Parsed and added a new bike."
  rescue
    # If there aren't any errors, don't add a thing.
    puts "There was an error parsing the page. No bike added."
  end
end

author = "fixedgearwizard@yahoo.com (Dennis Bean-Larson)"

# Build the RSS feed.
xml = Builder::XmlMarkup.new
xml.instruct! :xml, :version => "1.0", :encoding => 'UTF-8' 
xml.rss(:version => "2.0", 'xmlns:atom' => "http://www.w3.org/2005/Atom") do
  xml.channel do
    xml.title("Fixed Gear Gallery")
    xml.link("http://fixedgeargallery.com")
    xml.description("An Incredicble collection of fixed gear bicycles from around the world.")
    xml.language('en-us')
    xml.ttl(720)
    bikes.each do |bike|
      xml.item do
        xml.title(bike.name)
        xml.description do
          xml.cdata!(bike.text + "<br/><br/>" + bike.images)      
        end
        xml.author(author)               
        xml.pubDate(Time.now.strftime("%a, %d %b %Y %H:%M:%S %z"))
        xml.link(bike.link)
        xml.guid(bike.link)
      end
    end
    # Oh wow, this is a hack. Hooks into the protected _special method in Builder's XmlMarkup class.
    xml.__send__ :_special, '<atom:link', '/>', nil, { :href => 'http://deepyogurt.org/project/fggrss/fgg_rss.xml', :rel => 'self', :type => 'application/rss+xml' }
  end
end

# Write the xml out to a file.
begin
  File.open(File.dirname(__FILE__) + '/fgg_rss.xml', 'w') do |f|
    f << xml.to_s.gsub('<to_s/>', '') # Scrub the to_s tag that Builder akwardly inserts.
  end
rescue
  puts "Could not write XML to file."
end
