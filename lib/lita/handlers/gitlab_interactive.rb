require 'uri'

module Lita
  module Handlers
    class GitlabInteractive < Handler

      config :token
      config :host

      route(/(?:gl|issue)\s?\#?(\d+)/i, :get_default_issue, command: false, help: {
        'issue|gl #<issue number>' => 'looks up the issue for the default project in a room'
      })

      route(/gl\s+(.*\/.*)\s+\#?(\d+)/i, :get_project_issue, command: true, help: {
        'gl <namespace/project> #<issue number>' => 'looks up the issue for a names project'
      })

      route(/gl\s+set\s+(.*\/.*)/i, :set_default_project, command: true, help: {
        'gl set <namespace/project>' => 'Sets the default project for a room.'
      })

      route(/gl what is the default project/i, :get_default_project, command: true, help: {
        'gl what is the default project' => 'returns what the default project for this room is'
      })

      def get_project_issue(response)
        project_id = get_project_id_from_path(response.matches[0][0])
        project = get_project_from_id(project_id)
        issue = get_issue_of_project(project_id, response.matches[0][1])
        response.reply "##{issue['iid']}: #{issue['title']} #{project['web_url']}/issues/#{issue['iid']}"
      end

      def get_project_id_from_path(path)
        id = get_project_id(path)
        return id if id
        connection = Faraday.new config.host, :ssl => {:verify => false}
        project_response = connection.get do |req|
          req.url '/api/v3/projects/' + path.gsub('/', '%2F')
          req.headers['PRIVATE-TOKEN'] = config.token
        end
        hash = JSON.parse(project_response.body)
        id = hash["id"]
        set_project_id(path, id)
        id
      end

      def get_issue_of_project(project_id, issue_id)
        connection = Faraday.new config.host, :ssl => {:verify => false}
        project_response = connection.get do |req|
          req.url '/api/v3/projects/' + project_id.to_s + '/issues?iid=' + issue_id
          req.headers['PRIVATE-TOKEN'] = config.token
        end
        hash = JSON.parse(project_response.body)
        hash[0]
      end

      def get_project_from_id(project_id)
        connection = Faraday.new config.host, :ssl => {:verify => false}
        project_response = connection.get do |req|
          req.url '/api/v3/projects/' + project_id.to_s
          req.headers['PRIVATE-TOKEN'] = config.token
        end
        hash = JSON.parse(project_response.body)
        hash
      end

      def set_project_id(project, id)
        redis.set(project, id)
      end

      def get_project_id(project)
        redis.get(project)
      end

      def set_default_project(response)
        project_id = get_project_id_from_path(response.matches[0][0])
        room = response.message.source.room
        redis.set("default_room:#{room}", project_id)
        response.reply("OK I've made #{response.matches[0][0]} the default project")
      end

      def get_default_project(response)
        room = response.message.source.room
        project_id = redis.get("default_room:#{room}")
        project = get_project_from_id(project_id)
        response.reply project['name_with_namespace']
      end

      def get_default_issue(response)
        room = response.message.source.room
        project_id = redis.get("default_room:#{room}")
        issue = get_issue_of_project(project_id, response.matches[0][0])
        project = get_project_from_id(project_id)
        response.reply "##{issue['iid']}: #{issue['title']} #{project['web_url']}/issues/#{issue['iid']}"
      end
    end
    Lita.register_handler(GitlabInteractive)
  end
end
