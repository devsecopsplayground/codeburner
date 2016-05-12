#``
#The MIT License (MIT)
#
#Copyright (c) 2016, Groupon, Inc.
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in
#all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#THE SOFTWARE.
#
class Api::UserController < ApplicationController
  respond_to :json
  before_filter :authz
  #before_filter :fake_authz

  VALID_ATTRS = [ :id, :name, :fullname, :profile_url, :avatar_url ]
  WEBHOOK_URL = "http://appsec-codeburner1.snc1:8081/api/github/webhook"

  def index
    render(:json => @current_user, :only => VALID_ATTRS)
  end

  def show
    render(:json => User.find(params[:id]), :only => VALID_ATTRS)
  rescue ActiveRecord::RecordNotFound
    render(:json => {error: "no user with that id found"}, :status => 404)
  end

  def repos
    render(:json => @current_user.services)
  end

  def webhooks
    render(:json => Service.where(:webhook_user_id => @current_user.id))
  end

  def add_repo_hook
    repo = Service.find_or_create_by(:short_name => params[:repo])
    github = CodeburnerUtil.user_github(@current_user)

    result = github.create_hook(
      repo.short_name,
      'web',
      {
        :url => WEBHOOK_URL,
        :content_type => 'json'
      },
      {
        :events => ['push', 'pull_request'],
        :active => true
      }
    )

    if result
      repo.update(:webhook_user => @current_user, :html_url => github.repo(repo.short_name).html_url, :languages => github.languages(repo.short_name).to_hash.keys.join(", "))
      render(:json => {result: 'success'})
    else
      render(:json => {error: 'failed to add GitHub webhook'}, :status => 400)
    end
  rescue Octokit::UnprocessableEntity => e
    render(:json => {error: e.errors.first[:message]}, :status => 400)
  end

  def remove_repo_hook
    repo = Service.find(params[:repo])
    github = CodeburnerUtil.user_github(@current_user)
    hook = github.hooks(repo.short_name).detect {|h| h.config[:url] == WEBHOOK_URL}

    if hook
      result = github.remove_hook repo.short_name, hook.id
    else
      repo.update(:webhook_user => nil)
      return render(:json => {error: "No hook with that ID found"}, :status => 404)
    end

    if result
      repo.update(:webhook_user => nil)
      render(:json => {result: "success"})
    else
      render(:json => {error: "failed to remove hook"}, :status => 500)
    end
  rescue ActiveRecord::RecordNotFound
    return render(:json => {error: "No repo with that ID found"}, :status => 404)
  end


end