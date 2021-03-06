require 'spec_helper'

describe Repository do
  describe ".from_user" do
    it "rescues from a JSON parse error" do
      expect { Repository.from_user('') }.to_not raise_error
    end

    context "given valid user API data" do
      before do
        Repository.from_user(github('repo/tsigo'))
      end

      it "ignores private repositories" do
        Repository.where(owner: 'tsigo', name: 'super_secret').count.should eql(0)
      end

      it "ignores non-Ruby repositories" do
        Repository.where(owner: 'tsigo', name: 'cutup').count.should eql(0)
      end

      it "ignores forks" do
        Repository.where(owner: 'tsigo', name: 'wowr').count.should eql(0)
      end

      it "calls Repository.from_payload for valid repositories" do
        Repository.where(owner: 'tsigo', name: 'wriggle').count.should eql(1)
      end
    end
  end

  describe ".from_payload" do
    context "given invalid or private data" do
      it "ignores Hash data" do
        Repository.from_payload(foo: 'bar').should be_nil
      end

      it "rescues from a JSON parse error" do
        expect { Repository.from_payload('') }.to_not raise_error
      end

      it "ignores payloads without repository info" do
        payload = %{{"name": "repo"}}
        expect { Repository.from_payload(payload) }.to_not change(Repository, :count)
      end

      it "ignores private repositories" do
        expect { Repository.from_payload(github('push/private_repo')) }.to_not change(Repository, :count)
      end
    end

    context "given valid post-receieve data" do
      let(:repo) { Repository.from_payload(github('push/initial_push')) }

      it "extracts owner name" do
        repo.owner.should eql('tsigo')
      end

      it "sets name" do
        repo.name.should eql('hook_test')
      end

      it "sets description" do
        repo.description.should eql('')
      end

      it "sets fork" do
        repo.should_not be_fork
      end

      it "sets url" do
        repo.url.should eql('https://github.com/tsigo/hook_test')
      end

      it "sets homepage" do
        repo.homepage.should eql('')
      end

      it "sets watchers" do
        repo.watchers.should eql(1)
      end

      it "sets forks" do
        repo.forks.should eql(1)
      end

      it "enqueues GemfileJob for work" do
        Delayed::Job.expects(:enqueue).with { |v| v.class == GemfileJob }
        repo.should be_valid
      end
    end

    context "given valid API data" do
      let(:repo) { Repository.from_payload(github('repo/resque')) }

      it "sets owner name" do
        repo.owner.should eql('defunkt')
      end

      it "enqueues GemfileJob for work" do
        Delayed::Job.expects(:enqueue).with { |v| v.class == GemfileJob }
        repo.should be_valid
      end
    end

    context "given post-receive data for a repository we've already seen" do
      let(:data) { github('push/initial_push') }
      let(:repo) { Repository.from_payload(data) }

      before do
        repo.populate_gems(gemfile('simplest'))
      end

      context "payload contains no Gemfile modifications" do
        it "returns the existing repository" do
          Repository.from_payload(data).should eql(repo)
        end

        it "updates the existing repository" do
          repo.update(forks: 100)
          Repository.from_payload(data)
          repo.forks.should eql(1)
        end

        it "does not enqueue GemfileJob" do
          Delayed::Job.expects(:enqueue).never
          Repository.from_payload(data)
        end
      end

      context "when payload contains Gemfile modifications" do
        it "enqueues GemfileJob for work" do
          Delayed::Job.expects(:enqueue).with { |v| v.class == GemfileJob }

          # Use a payload that contains Gemfile modifications in the same
          # repository as "initial_push" from above
          Repository.from_payload(github('push/modify_gemfile'))
        end
      end
    end
  end

  describe "#populate_gems" do
    let(:repo) { Factory(:repository) }

    context "given valid data" do
      it "populates gem records" do
        gemstr = gemfile('simplest')

        expect { repo.populate_gems(gemstr) }.to change(repo.gems, :count).from(0).to(2)
      end

      it "removes old gem records before adding new ones" do
        # Add "old" gems
        repo.populate_gems(gemfile('simplest'))

        repo.populate_gems(gemfile('grouping'))
        repo.gems.any? { |g| g.name == 'rails' }.should be_false
        repo.gems.any? { |g| g.name == 'cucumber' }.should be_true
      end
    end

    context "given empty data" do
      it "does not raise an error" do
        expect { repo.populate_gems('[]') }.to_not raise_error
      end
    end
  end

  describe "#gem_counts" do
    it "updates GemCount after create" do
      3.times do
        repo = Factory(:repository)
        repo.populate_gems('[{"name":"gemphile","version":""}]')
      end

      Repository.gem_counts.first.should eql({name: 'gemphile', count: 3})
    end

    it "updates counts after destroy" do
      3.times do
        repo = Factory(:repository)
        repo.populate_gems('[{"name":"gemphile","version":""}]')
      end

      Repository.last.destroy
      Repository.gem_counts.first.should eql({name: 'gemphile', count: 2})
    end
  end
end
