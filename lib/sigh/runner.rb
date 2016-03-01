require 'spaceship'

module Sigh
  class Runner
    attr_accessor :spaceship

    # Uses the spaceship to create or download a provisioning profile
    # returns the path the newly created provisioning profile (in /tmp usually)
    def run
      FastlaneCore::PrintTable.print_values(config: Sigh.config,
                                         hide_keys: [:output_path],
                                             title: "Summary for sigh #{Sigh::VERSION}")

      UI.message "Starting login with user '#{Sigh.config[:username]}'"
      Spaceship.login(Sigh.config[:username], nil)
      Spaceship.select_team
      UI.message "Successfully logged in"
      Spaceship.

      profiles = [] if Sigh.config[:skip_fetch_profiles]
      profiles ||= fetch_profiles # download the profile if it's there
    
      if Sigh.config[:device_id] && Sigh.config[:device_name]
        Spaceship.device.create!(name: Sigh.config[:device_name]  ,udid: Sigh.config[:device_id] )
      end 

      if profiles.count > 0
        UI.success "Found #{profiles.count} matching profile(s)"
        profile = profiles.first

        if Sigh.config[:force]
          if profile_type == Spaceship.provisioning_profile::AppStore or profile_type == Spaceship.provisioning_profile::InHouse
            UI.important "Updating the provisioning profile"
          else
            UI.important "Updating the profile to include all devices"
            profile.devices = Spaceship.device.all_for_profile_type(profile.type)
          end

          profile = profile.update! # assign it, as it's a new profile
        end
      else
        UI.important "No existing profiles found, that match the certificates you have installed, creating a new one for you"
        profile = create_profile!
      end

      UI.user_error!("Something went wrong fetching the latest profile") unless profile

      if profile_type == Spaceship.provisioning_profile.in_house
        ENV["SIGH_PROFILE_ENTERPRISE"] = "1"
      else
        ENV.delete("SIGH_PROFILE_ENTERPRISE")
      end

      return download_profile(profile)
    end

    # The kind of provisioning profile we're interested in
    def profile_type
      return @profile_type if @profile_type

      @profile_type = Spaceship.provisioning_profile.development

      @profile_type
    end

    # Fetches a profile matching the user's search requirements
    def fetch_profiles
      UI.message "Fetching profiles...#{Sigh.config[:app_identifier]}"
      results = profile_type.find_by_bundle_id(Sigh.config[:app_identifier])

       #Take the provisioning profile name into account
      #if Sigh.config[:provisioning_name].to_s.length > 0
        #filtered = results.select { |p| p.name.strip == Sigh.config[:provisioning_name].strip }
        #if Sigh.config[:ignore_profiles_with_different_name]
          #results = filtered
        #else
          #results = filtered if (filtered || []).count > 0
        #end
      #end

      if results 
        return [results]
      else
        return []
      end
      


      #return results if Sigh.config[:skip_certificate_verification]

      #return results.find_all do |a|
        ## Also make sure we have the certificate installed on the local machine
        #installed = false
        #a.certificates.each do |cert|
          #file = Tempfile.new('cert')
          #file.write(cert.download_raw)
          #file.close
          #installed = true if FastlaneCore::CertChecker.installed?(file.path)
        #end
        #installed
      #end
    end

    # Create a new profile and return it
    def create_profile!
      bundle_id = Sigh.config[:app_identifier]
      name ="xiaoming123"

      UI.important "Creating new provisioning profile for '#{Sigh.config[:app_identifier]}' with name '#{Sigh.config[:app_identifier]}'"
      profile = profile_type.create!(name: name,
                                    bundle_id: bundle_id)
      profile
    end


    # Downloads and stores the provisioning profile
    def download_profile(profile)
      UI.important "Downloading provisioning profile..."
      profile_name ||= "#{profile.class.pretty_type}_#{Sigh.config[:app_identifier]}.mobileprovision" # default name
      profile_name += '.mobileprovision' unless profile_name.include? 'mobileprovision'

      tmp_path = Dir.mktmpdir("profile_download")
      output_path = File.join(tmp_path, profile_name)
      File.open(output_path, "wb") do |f|
        f.write(profile.download)
      end

      UI.success "Successfully downloaded provisioning profile..."
      return output_path
    end

    def print_produce_command(config)
      UI.message ""
      UI.message "==========================================".yellow
      UI.message "Could not find App ID with bundle identifier '#{config[:app_identifier]}'"
      UI.message "You can easily generate a new App ID on the Developer Portal using 'produce':"
      UI.message ""
      UI.message "produce -u #{config[:username]} -a #{config[:app_identifier]} --skip_itc".yellow
      UI.message ""
      UI.message "You will be asked for any missing information, like the full name of your app"
      UI.message "If the app should also be created on iTunes Connect, remove the " + "--skip_itc".yellow + " from the command above"
      UI.message "==========================================".yellow
      UI.message ""
    end
  end
end
