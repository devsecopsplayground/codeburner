#
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
class ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session
  rescue_from Octokit::Unauthorized, :with => :github_auth_error

  def admin_only
    if User.admin.count > 0
      unless @current_user and @current_user.admin?
        render(:json => {:error => 'Administrator role required'}, :status => 403)
      end
    end
  end

  private
    def fake_authz
      @current_user = User.first
    end

    def authz
      return render(:json => {:error => 'Authentication via GitHub OAuth or API token required'}, :status => 403) if request.headers['Authorization'].nil?

      begin
        type, token = request.headers['Authorization'].split(' ')

        type.downcase!

        if type == 'jwt'
          uid = JWT.decode(token, Rails.application.secrets.secret_key_base)[0]['uid']
        elsif type == 'bearer'
          uid = Token.find_by(token: token).user.github_uid
        else
           return render(:json => {:error => 'Authentication via GitHub OAuth or API token required'}, :status => 403)
        end

        @current_user = User.find_by(github_uid: uid)
      rescue JWT::DecodeError, ActiveRecord::RecordNotFound
        render(:json => {:error => 'Authentication via GitHub OAuth or API token required'}, :status => 403)
      end
    end

    def authz_no_fail
      begin
        type, token = request.headers['Authorization'].split(' ')

        if type == 'JWT'
          uid = JWT.decode(token, Rails.application.secrets.secret_key_base)[0]['uid']
        elsif type == 'Bearer'
          uid = Token.find_by(token: token).user.github_uid
        else
           return render(:json => {:error => 'Authentication via GitHub OAuth or API token required'}, :status => 403)
        end

        @current_user = User.find_by(github_uid: uid)
      rescue JWT::DecodeError
        @current_user = nil
      end
    end

    def github_auth_error
      render(:json => {error: 'GitHub authorization failure.  Try logging in again.'}, :status => 401)
    end

end
