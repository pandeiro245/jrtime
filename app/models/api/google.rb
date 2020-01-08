class Api::Google
  def initialize
    @credentials = Google::Auth::UserRefreshCredentials.new(
      additional_parameters: {
        access_type: 'offline',
        include_granted_scopes: 'true',
        prompt: 'consent'
      },
      client_id: ENV['GOOGLE_KEY'],
      client_secret: ENV['GOOGLE_SECRET'],
      scope: [
        'https://www.googleapis.com/auth/drive',
        'https://spreadsheets.google.com/feeds/'
      ],
      redirect_uri: 'https://245cloud.com'
    )
    _token = ENV['GOOGLE_TOKEN']
    @credentials.refresh_token = _token
    @credentials.fetch_access_token!
  end

  def gdrive
    GoogleDrive::Session.from_credentials(@credentials)
  end
end
