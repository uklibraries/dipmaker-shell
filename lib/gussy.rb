#!/usr/bin/env ruby

require 'json'
require 'nokogiri'

def component_xpath
    (1..12).collect {|number|
        %-//xmlns:dsc//xmlns:c#{sprintf "%02d", number}[xmlns:did//xmlns:container and not(.//xmlns:c#{sprintf "%02d", number+1})]-
    }.push(
       %-//xmlns:dsc//xmlns:c[xmlns:did//xmlns:container and not(.//xmlns:c)]-
    ).join('|')
end

def old_render(container, prefix)
    container_number = container.content.strip.downcase
    container_number.gsub!(/[^a-z0-9]/, '_')
    "#{prefix}_#{container_number}"
end

def render(container)
    container_type = 'container'
    container_number = container.content.strip.downcase
    container_number.gsub!(/[^a-z0-9]/, '_')
    raw_type = container['type'].strip.downcase
    raw_type.gsub!(/[^a-z0-9]/, '_')
    if raw_type.length > 0
        if raw_type === 'othertype'
            raw_label = container['label'].strip.downcase
            raw_label.gsub!(/[^a-z0-9]/, '_')
            if raw_label.length > 0
                container_type = raw_label
            end
        else
            container_type = raw_type
        end
    end
    container_type.capitalize!
    [container_type, container_number].join('_')
end

def container_lists_for(xml, base)
    seen = {}
    h = {old: [], new: [], candidates: {}}
    pos = 0
    xml.xpath(component_xpath).select {|component|
        # We need to handle multiple container lists in both old and new styles
        simple = true
        component.xpath('xmlns:did/xmlns:container').each do |container|
            if container['parent']
                simple = false
                break
            end
        end

        if simple
            old_path_components = []
            prefix = base
            path_components = component.xpath('xmlns:did/xmlns:container').map do |container|
                prefix = old_render(container, prefix)
                old_path_components << prefix
                render(container)
            end
            paths = [path_components.join('/')]
            old_paths = [old_path_components.join('/')]
        else
            section = {}
            section_ids = []
            component.xpath('xmlns:did/xmlns:container').each do |container|
                if container['parent']
                    # Add this container to the parent's section
                    section[container['parent']] << container.dup
                    section[container['id']] = section[container['parent']]
                else
                    # Create a new section
                    section[container['id']] = [container.dup]
                    section_ids << container['id']
                end
            end
            paths = section_ids.collect do |id|
                section[id].map {|c| render(c)}.join('/')
            end
            old_paths = section_ids.collect do |id|
                prefix = base
                section[id].map {|c|
                    prefix = old_render(c, prefix)
                }.join('/')
            end
        end

        paths = paths.collect do |path|
            File.join base, path
        end

        old_paths = old_paths.collect do |path|
            File.join base, path
        end

        h[:new] << paths
        h[:old] << old_paths

        old_paths.each do |old_path|
            seen[old_path] ||= {}
            h[:candidates][old_path] ||= []
            paths.each do |path|
                if not(seen[old_path].has_key?(paths))
                    seen[old_path][paths] = 1
                    h[:candidates][old_path] << path
                end
            end
        end
    }
    h
end
