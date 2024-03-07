require File.dirname(__FILE__) + '/../spec_helper'

describe "find_objects" do
  describe "simple matching" do
    subject{ new_controller(fixture("dsl/load.eye")) }

    it "matched_objects" do
      res = subject.matched_objects("p1")
      expect(res[:result]).to eq %w{app1:gr1:p1}
    end

    it "1 process" do
      objs = subject.find_objects("p1")
      expect(objs.class).to eq Eye::Utils::AliveArray
      expect(objs.map(&:full_name).sort).to eq %w{app1:gr1:p1}
      expect(objs.map(&:class)).to eq [Eye::Process]
    end

    it "1 group" do
      objs = subject.find_objects("gr2")
      expect(objs.map(&:full_name).sort).to eq %w{app1:gr2}
      expect(objs.map(&:class)).to eq [Eye::Group]
    end

    it "1 app" do
      objs = subject.find_objects("app2")
      expect(objs.map(&:full_name).sort).to eq %w{app2}
      expect(objs.map(&:class)).to eq [Eye::Application]
    end

    it "find * processes by mask" do
      objs = subject.find_objects("p*")
      expect(objs.map(&:full_name).sort).to eq %w{app1:gr1:p1 app1:gr1:p2}
    end

    it "find * groups by mask" do
      objs = subject.find_objects("gr*")
      expect(objs.map(&:full_name).sort).to eq %w{app1:gr1 app1:gr2}
    end

    it "find * apps by mask" do
      objs = subject.find_objects("app*")
      expect(objs.map(&:full_name).sort).to eq %w{app1 app2}
    end

    it "find by ','" do
      objs = subject.find_objects("p1,p2")
      expect(objs.map(&:full_name).sort).to eq %w{app1:gr1:p1 app1:gr1:p2}
    end

    it "find by ',' with empty part" do
      objs = subject.find_objects("p1,")
      expect(objs.map(&:full_name).sort).to eq %w{app1:gr1:p1}
    end

    it "find by many params" do
      objs = subject.find_objects("p1", "p2")
      expect(objs.map(&:full_name).sort).to eq %w{app1:gr1:p1 app1:gr1:p2}
    end

    it "find * apps by mask" do
      objs = subject.find_objects("z*\n")
      expect(objs.map(&:full_name).sort).to eq %w{app2:z1}
    end

    it "'all', find all projects" do
      objs = subject.find_objects("all")
      expect(objs.map(&:full_name).sort).to eq %w{app1 app2}
    end

    it "'*', find all projects" do
      objs = subject.find_objects("*")
      expect(objs.map(&:full_name).sort).to eq %w{app1 app2}
    end

    it "nothing" do
      expect(subject.find_objects("")).to eq []
      expect(subject.find_objects("asdfasdf")).to eq []
      expect(subject.find_objects("2")).to eq []
      expect(subject.find_objects("pp")).to eq []
    end

    describe "submatching without * " do
      it "match by start symbols, apps" do
        objs = subject.find_objects("app")
        expect(objs.map(&:full_name).sort).to eq %w{app1 app2}
      end

      it "match by start symbols, groups" do
        objs = subject.find_objects("gr")
        expect(objs.map(&:full_name).sort).to eq %w{app1:gr1 app1:gr2}
      end

      it "match by start symbols, process" do
        objs = subject.find_objects("z")
        expect(objs.map(&:full_name).sort).to eq %w{app2:z1}
      end
    end

    describe "find by routes" do
      it "group" do
        objs = subject.find_objects("app1:gr2")
        expect(objs.map(&:full_name).sort).to eq %w{app1:gr2}
      end

      it "group + mask" do
        objs = subject.find_objects("app1:gr*")
        expect(objs.map(&:full_name).sort).to eq %w{app1:gr1 app1:gr2}
      end

      it "process" do
        objs = subject.find_objects("app1:gr2:q3")
        expect(objs.map(&:full_name).sort).to eq %w{app1:gr2:q3}
      end
    end

    describe "missing" do
      it "should not found" do
        expect(subject.find_objects("app1:gr4")).to eq []
        expect(subject.find_objects("gr:p")).to eq []
        expect(subject.find_objects("pp1")).to eq []
        expect(subject.find_objects("app1::")).to eq []
        expect(subject.find_objects("app1:=")).to eq []
        expect(subject.find_objects("* *")).to eq []
        expect(subject.find_objects(",")).to eq []
      end
    end

    describe "match" do
      it "should match" do
        expect(subject.command(:match, "gr*")[:result]).to eq ["app1:gr1", "app1:gr2"]
      end
    end
  end


  describe "dupls" do
    subject{ new_controller(fixture("dsl/load_dupls.eye")) }

    it "not found" do
      expect(subject.find_objects("zu")).to eq []
    end

    it "found 2 processed" do
      objs = subject.find_objects("z*")
      expect(objs.map(&:full_name).sort).to eq %w{app2:gr1:z2 app2:z1}
    end

    it "find by gr1" do
      expect{
        subject.find_objects("gr1")
      }.to raise_error(Eye::Controller::Error)
    end

    it "raised by gr*" do
      expect{
        objs = subject.find_objects("gr*")
      }.to raise_error(Eye::Controller::Error)
    end

    it "should not raise if mask starts with *" do
      objs = subject.find_objects("*gr1")
      expect(objs.map(&:full_name).sort).to eq %w{app1:gr1 app2:gr1}
      objs = subject.find_objects("*gr*")
      expect(objs.map(&:full_name).sort).to eq ["app1:gr1", "app1:gr2", "app1:gr2and", "app2:gr1", "app5:gr7"]
    end

    it "correct by app1:gr*" do
      objs = subject.find_objects("app1:gr*")
      expect(objs.map(&:full_name)).to eq %w{app1:gr1 app1:gr2 app1:gr2and}
    end

    it "correct process" do
      objs = subject.find_objects("gr1and")
      expect(objs.map(&:full_name).sort).to eq %w{app2:gr1:gr1and}
    end
  end

  describe "exactly matching" do
    subject{ new_controller(fixture("dsl/load_dupls.eye")) }

    it "find 1 process by short name" do
      objs = subject.find_objects("some")
      expect(objs.class).to eq Eye::Utils::AliveArray
      expect(objs.map(&:full_name).sort).to eq %w{app5:some}
    end

    it "find 1 process by short name" do
      objs = subject.find_objects("mu")
      expect(objs.map(&:full_name).sort).to eq %w{app5:gr7:mu}
    end

    it "find 1 process by full name" do
      objs = subject.find_objects("app5:some")
      expect(objs.map(&:full_name).sort).to eq %w{app5:some}
    end

    it "find 1 process by full name and mask" do
      objs = subject.find_objects("app*:some")
      expect(objs.map(&:full_name).sort).to eq %w{app5:some}
    end

    it "find 1 process by full name and mask" do
      objs = subject.find_objects("*some")
      expect(objs.map(&:full_name).sort).to eq %w{app5:some}
    end

    it "2 targets" do
      objs = subject.find_objects("some", "am")
      expect(objs.map(&:full_name).sort).to eq %w{app5:am app5:some}
    end

    it "2 targets with multi" do
      objs = subject.find_objects("some", "am*")
      expect(objs.map(&:full_name).sort).to eq %w{app5:am app5:am2 app5:some}
    end

    it "with group" do
      objs = subject.find_objects("some", "*gr7:mu")
      expect(objs.map(&:full_name).sort).to eq %w{app5:gr7:mu app5:some}
    end

    it "find multiple by not exactly match" do
      objs = subject.find_objects("som")
      expect(objs.map(&:full_name).sort).to eq %w{app5:some app5:some2 app5:some_name}
    end

    it "find multiple by exactly with *" do
      objs = subject.find_objects("some*")
      expect(objs.map(&:full_name).sort).to eq %w{app5:some app5:some2 app5:some_name}
    end

    it "find multiple by exactly with *" do
      objs = subject.find_objects("*some*")
      expect(objs.map(&:full_name).sort).to eq %w{app5:some app5:some2 app5:some_name}
    end

    it "in different apps" do
      expect {
        objs = subject.find_objects("one")
      }.to raise_error(Eye::Controller::Error)
    end

    it "when exactly matched object and subobject" do
      objs = subject.find_objects("serv")
      expect(objs.map(&:full_name).sort).to eq %w{app5:serv}
    end
  end

  describe "Not allow objects from different apps" do
    subject{ new_controller(fixture("dsl/load_dupls2.eye")) }

    it "`admin` should not match anything" do
      expect {
        objs = subject.find_objects("admin")
      }.to raise_error(Eye::Controller::Error)
    end

    it "`zoo` should not match anything" do
      expect {
        objs = subject.find_objects("zoo")
      }.to raise_error(Eye::Controller::Error)
    end

    it "`e1` should not match anything" do
      expect {
        objs = subject.find_objects("e1")
      }.to raise_error(Eye::Controller::Error)
    end

    it "`koo` should match group" do
      objs = subject.find_objects("koo")
      expect(objs.map(&:full_name).sort).to eq %w{app2:koo}
    end

    it "`*admin` should match" do
      expect(subject.find_objects("*admin").size).to eq 2
    end

    it "`*zoo` should match" do
      expect(subject.find_objects("*zoo").size).to eq 2
    end

    it "`*e1` should not match anything" do
      expect(subject.find_objects("*e1").size).to eq 2
    end

    it "`*:e1` should not match anything" do
      expect(subject.find_objects("*:e1").size).to eq 2
    end

    it "`*p1` should match app1" do
      objs = subject.find_objects("*p1")
      expect(objs.map(&:full_name).sort).to eq %w{app1}
    end

    it "`app1:admin` should match" do
      objs = subject.find_objects("app1:admin")
      expect(objs.map(&:full_name).sort).to eq %w{app1:admin}
    end

    it "multiple targets allowed" do
      objs = subject.find_objects("app1:admin", "app2:admin")
      expect(objs.map(&:full_name).sort).to eq %w{app1:admin app2:admin}
    end

    it "matched_objects" do
      res = subject.matched_objects("admin")
      expect(res[:error]).to eq 'cannot match targets from different applications: ["app1:admin", "app2:admin"]'
    end
  end

  describe "matching app in priority" do
    subject{ new_controller(fixture("dsl/load_dupls3.eye")) }

    it "`some` should find only app" do
      objs = subject.find_objects("some")
      expect(objs.map(&:full_name).sort).to eq %w{someapp}
    end

    it "`someapp` should find only app" do
      objs = subject.find_objects("someapp")
      expect(objs.map(&:full_name).sort).to eq %w{someapp}
    end

    it "`somep` should find only process" do
      objs = subject.find_objects("somep")
      expect(objs.map(&:full_name).sort).to eq %w{app:someprocess}
    end

    it 'app should raise error' do
      objs = subject.find_objects("app")
      expect(objs.map(&:full_name).sort).to eq %w{app}
    end
  end

  describe "matching app in priority" do
    subject{ with_temp_file(<<-E){ |f| new_controller(f) }
      Eye.application "worder" do
        group "word1" do
          process("p1"){ pid_file "p1" }
        end

        group :bigword do
          process("o1"){ pid_file "o1" }
        end
      end
    E
    }

    it "`word` should match app" do
      objs = subject.find_objects("word")
      expect(objs.map(&:full_name).sort).to eq %w{worder}
    end

    it "`word*` should match app" do
      objs = subject.find_objects("word*")
      expect(objs.map(&:full_name).sort).to eq %w{worder}
    end
  end

  describe "application filter" do
    subject{ new_controller(fixture("dsl/load.eye")) }

    it "when unknown application" do
      res = subject.matched_objects("p1", :application => "crazey")
      expect(res[:result]).to eq %w{}
    end

    it "*" do
      res = subject.matched_objects("*", :application => "app1")
      expect(res[:result]).to eq %w{app1}

      res = subject.matched_objects("*", :application => "app2")
      expect(res[:result]).to eq %w{app2}
    end

    it "all" do
      res = subject.matched_objects("all", :application => "app1")
      expect(res[:result]).to eq %w{app1}

      res = subject.matched_objects("all", :application => "app2")
      expect(res[:result]).to eq %w{app2}
    end

    it "p1" do
      res = subject.matched_objects("p1", :application => "app1")
      expect(res[:result]).to eq %w{app1:gr1:p1}

      res = subject.matched_objects("p1", :application => "app2")
      expect(res[:result]).to eq %w{}
    end

    it "find p* processes by mask" do
      objs = subject.find_objects("p*", :application => "app1")
      expect(objs.map(&:full_name).sort).to eq %w{app1:gr1:p1 app1:gr1:p2}
    end

    it "z1" do
      res = subject.matched_objects("z1", :application => "app1")
      expect(res[:result]).to eq %w{}

      res = subject.matched_objects("z1", :application => "app2")
      expect(res[:result]).to eq %w{app2:z1}
    end

    it "not matched app partially" do
      res = subject.matched_objects("p1", :application => "app")
      expect(res[:result]).to eq %w{}
    end
  end

end
