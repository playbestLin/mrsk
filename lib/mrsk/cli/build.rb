class Mrsk::Cli::Build < Mrsk::Cli::Base
  desc "deliver", "Build app and push app image to registry then pull image on servers"
  def deliver
    with_lock do
      push
      pull
    end
  end

  desc "push", "Build and push app image to registry"
  def push
    with_lock do
      cli = self

      run_locally do
        begin
          MRSK.with_verbosity(:debug) { execute *MRSK.builder.push }
        rescue SSHKit::Command::Failed => e
          if e.message =~ /(no builder)|(no such file or directory)/
            error "Missing compatible builder, so creating a new one first"

            if cli.create
              MRSK.with_verbosity(:debug) { execute *MRSK.builder.push }
            end
          else
            raise
          end
        end
      end
    end
  end

  desc "pull", "Pull app image from registry onto servers"
  def pull
    with_lock do
      on(MRSK.hosts) do
        execute *MRSK.auditor.record("Pulled image with version #{MRSK.config.version}"), verbosity: :debug
        execute *MRSK.builder.clean, raise_on_non_zero_exit: false
        execute *MRSK.builder.pull
      end
    end
  end

  desc "create", "Create a build setup"
  def create
    with_lock do
      run_locally do
        begin
          debug "Using builder: #{MRSK.builder.name}"
          execute *MRSK.builder.create
        rescue SSHKit::Command::Failed => e
          if e.message =~ /stderr=(.*)/
            error "Couldn't create remote builder: #{$1}"
            false
          else
            raise
          end
        end
      end
    end
  end

  desc "remove", "Remove build setup"
  def remove
    with_lock do
      run_locally do
        debug "Using builder: #{MRSK.builder.name}"
        execute *MRSK.builder.remove
      end
    end
  end

  desc "details", "Show build setup"
  def details
    run_locally do
      puts "Builder: #{MRSK.builder.name}"
      puts capture(*MRSK.builder.info)
    end
  end
end
