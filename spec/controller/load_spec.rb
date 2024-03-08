require File.dirname(__FILE__) + '/../spec_helper'

RSpec.describe "Eye::Controller::Load" do
  subject{ Eye::Controller.new }

  it "command load exclusive" do
    futures = []
    should_spend(1.2, 0.2) do
      futures << subject.future.command('load', fixture("dsl/just_sleep.eye"))
      futures << subject.future.command('load', fixture("dsl/just_sleep.eye"))

      expect(futures.map(&:value).map{ |r| r.values.first[:error] }).to eq [false, false]
    end
  end

  it "should set :current_config as Eye::Config class" do
    subject.load(fixture("dsl/load.eye"))

    cfg = subject.current_config
    expect(cfg.class).to eq Eye::Config
    expect(cfg.applications).not_to be_empty
    expect(cfg.settings).to eq({})
  end

  it "benchmark" do
    100.times do
      subject.load(fixture("dsl/load.eye"))
    end
  end

  it "blank" do
    expect(subject.load).to eq({})
  end

  it "not exists file" do
    expect(subject).to receive(:set_proc_line)
    res = subject.load("/asdf/asd/fasd/fas/df/sfd")
    expect(res["/asdf/asd/fasd/fas/df/sfd"][:error]).to eq true
    expect(res["/asdf/asd/fasd/fas/df/sfd"][:message]).to include("/asdf/asd/fasd/fas/df/sfd")
  end

  it "load 1 ok app" do
    res = subject.load(fixture("dsl/load.eye"))
    expect(res).to be_ok

    expect(subject.short_tree).to eq({
      "app1"=>{
        "gr1"=>{"p1"=>"/tmp/app1-gr1-p1.pid", "p2"=>"/tmp/app1-gr1-p2.pid"},
        "gr2"=>{"q3"=>"/tmp/app1-gr2-q3.pid"},
        "__default__"=>{"g4"=>"/tmp/app1-g4.pid", "g5"=>"/tmp/app1-g5.pid"}},
      "app2"=>{"__default__"=>{"z1"=>"/tmp/app2-z1.pid"}}})

    expect(res.size).to eq(1)
    expect(res.values.first).to eq({ :error => false, :config => nil })
  end

  it "can accept options" do
    expect(subject.load(fixture("dsl/load.eye"), :some => 1)).to be_ok
  end

  it "work fine throught command" do
    expect(subject.command(:load, fixture("dsl/load.eye"))).to be_ok
  end

  it "load correctly application, groups for full_names processes" do
    expect(subject.load(fixture("dsl/load.eye"))).to be_ok

    p1 = subject.process_by_name('p1')
    expect(p1[:application]).to eq 'app1'
    expect(p1[:group]).to eq 'gr1'
    expect(p1.name).to eq 'p1'
    expect(p1.full_name).to eq 'app1:gr1:p1'

    gr1 = subject.group_by_name 'gr1'
    expect(gr1.full_name).to eq 'app1:gr1'
    expect(subject.applications.detect{|c| c.name == 'app1'}.groups).to be_a(Eye::Utils::AliveArray)
    expect(subject.applications.detect{|c| c.name == 'app1'}.groups.detect{|g| g.name == 'gr1'}.processes).to be_a(Eye::Utils::AliveArray)

    g4 = subject.process_by_name('g4')
    expect(g4[:application]).to eq 'app1'
    expect(g4[:group]).to eq '__default__'
    expect(g4.name).to eq 'g4'
    expect(g4.full_name).to eq 'app1:g4'
  end

  it "load + 1new app" do
    expect(subject.load(fixture("dsl/load.eye"))).to be_ok
    expect(subject.short_tree).to eq({
      "app1"=>{
        "gr1"=>{"p1"=>"/tmp/app1-gr1-p1.pid", "p2"=>"/tmp/app1-gr1-p2.pid"},
        "gr2"=>{"q3"=>"/tmp/app1-gr2-q3.pid"},
        "__default__"=>{"g4"=>"/tmp/app1-g4.pid", "g5"=>"/tmp/app1-g5.pid"}},
      "app2"=>{"__default__"=>{"z1"=>"/tmp/app2-z1.pid"}}
    })

    expect(subject.load(fixture("dsl/load2.eye"))).to be_ok

    expect(subject.short_tree).to eq({
      "app1"=>{
        "gr1"=>{"p1"=>"/tmp/app1-gr1-p1.pid", "p2"=>"/tmp/app1-gr1-p2.pid"},
        "gr2"=>{"q3"=>"/tmp/app1-gr2-q3.pid"},
        "__default__"=>{"g4"=>"/tmp/app1-g4.pid", "g5"=>"/tmp/app1-g5.pid"}},
      "app2"=>{"__default__"=>{"z1"=>"/tmp/app2-z1.pid"}},
      "app3"=>{"__default__"=>{"e1"=>"/tmp/app3-e1.pid"}}
    })
  end

  it "load 1 changed app" do
    expect(subject.load(fixture("dsl/load.eye"))).to be_ok
    expect(subject.load(fixture("dsl/load2.eye"))).to be_ok

    p = subject.process_by_name('e1')
    expect(p[:daemonize]).to eq false

    expect(p.wrapped_object).to receive(:schedule).with({ command: :update_config, args: kind_of(Array) }).and_call_original
    expect(p.wrapped_object).not_to receive(:schedule).with(:monitor)

    expect(p.logger.prefix).to eq 'app3:e1'

    expect(subject.load(fixture("dsl/load3.eye"))).to be_ok

    expect(subject.short_tree).to eq({
      "app1"=>{
        "gr1"=>{"p1"=>"/tmp/app1-gr1-p1.pid", "p2"=>"/tmp/app1-gr1-p2.pid"},
        "gr2"=>{"q3"=>"/tmp/app1-gr2-q3.pid"},
        "__default__"=>{"g4"=>"/tmp/app1-g4.pid", "g5"=>"/tmp/app1-g5.pid"}},
      "app2"=>{"__default__"=>{"z1"=>"/tmp/app2-z1.pid"}},
      "app3"=>{"wow"=>{"e1"=>"/tmp/app3-e1.pid"}}
    })

    sleep 0.1
    p2 = subject.process_by_name('e1')
    expect(p2[:daemonize]).to eq true

    expect(p.object_id).to eq p2.object_id
    expect(p.logger.prefix).to eq 'app3:wow:e1'
  end

  it "load -> delete -> load" do
    expect(subject.load(fixture("dsl/load.eye"))).to be_ok
    expect(subject.load(fixture("dsl/load2.eye"))).to be_ok
    subject.command(:delete, 'app3')
    expect(subject.load(fixture("dsl/load3.eye"))).to be_ok

    expect(subject.short_tree).to eq({
      "app1"=>{
        "gr1"=>{"p1"=>"/tmp/app1-gr1-p1.pid", "p2"=>"/tmp/app1-gr1-p2.pid"},
        "gr2"=>{"q3"=>"/tmp/app1-gr2-q3.pid"},
        "__default__"=>{"g4"=>"/tmp/app1-g4.pid", "g5"=>"/tmp/app1-g5.pid"}},
      "app2"=>{"__default__"=>{"z1"=>"/tmp/app2-z1.pid"}},
      "app3"=>{"wow"=>{"e1"=>"/tmp/app3-e1.pid"}}
    })
  end

  it "load + 1 app, and pid_file crossed" do
    expect(subject.load(fixture("dsl/load2.eye"))).to be_ok
    res = subject.load(fixture("dsl/load4.eye"))
    expect(res.size).to eq(1)
    expect(res.values.first).to include(:error => true, :message => "duplicate pid_files: {\"/tmp/app3-e1.pid\"=>2}")

    expect(subject.short_tree).to eq({
      "app3"=>{"__default__"=>{"e1"=>"/tmp/app3-e1.pid"}}
    })
  end

  it "check syntax" do
    res = subject.command(:check, fixture("dsl/load_dup_ex_names3.eye"))
    expect(res.size).to eq(1)
    expect(res.values.first).to include(:error => true)
  end

  it "check explain" do
    res = subject.command(:explain, fixture("dsl/load2.eye"))
    expect(res.size).to eq(1)
    expect(res.values[0][:error]).to eq false
    expect(res.values[0][:config].is_a?(Hash)).to eq true
  end

  it "process and groups disappears" do
    expect(subject.load(fixture("dsl/load.eye"))).to be_ok
    expect(subject.group_by_name('gr1').processes.full_size).to eq 2

    expect(subject.load(fixture("dsl/load5.eye"))).to be_ok
    sleep 0.5

    group_actors = Celluloid::Actor.all.select{|c| c.class == Eye::Group }
    process_actors = Celluloid::Actor.all.select{|c| c.class == Eye::Process }

    expect(subject.short_tree).to eq({
      "app1"=>{"gr1"=>{"p1"=>"/tmp/app1-gr1-p1.pid"}},
      "app2"=>{"__default__"=>{"z1"=>"/tmp/app2-z1.pid"}}
    })

    expect(group_actors.map{|a| a.name}.sort).to eq %w{__default__ gr1}
    expect(process_actors.map{|a| a.name}.sort).to eq %w{p1 z1}

    expect(subject.group_by_name('gr1').processes.full_size).to eq 1

    # terminate 1 action
    subject.process_by_name('p1').terminate
    expect(subject.info_data).to be_a(Hash)
  end

  it "swap groups" do
    expect(subject.load(fixture("dsl/load.eye"))).to be_ok
    expect(subject.load(fixture("dsl/load6.eye"))).to be_ok

    expect(subject.short_tree).to eq({
      "app1" => {
        "gr2"=>{"p1"=>"/tmp/app1-gr1-p1.pid", "p2"=>"/tmp/app1-gr1-p2.pid"},
        "gr1"=>{"q3"=>"/tmp/app1-gr2-q3.pid"},
        "__default__"=>{"g4"=>"/tmp/app1-g4.pid", "g5"=>"/tmp/app1-g5.pid"}},
      "app2"=>{"__default__"=>{"z1"=>"/tmp/app2-z1.pid"}}
    })
  end

  it "two configs with same pids (should validate final config)" do
    expect(subject.load(fixture("dsl/load.eye"))).to be_ok
    res = subject.load(fixture("dsl/load2{,_dup_pid,_dup2}.eye"))
    expect(res.size).to eq 3
    expect(res).to have_error_count 1
    expect(res.keys.grep(/load2_dup_pid\.eye/).values).to eq([
      hash_including(:error => true, :message=>"duplicate pid_files: {\"/tmp/app3-e1.pid\"=>2}"),
    ])
  end

  it "two configs with same pids (should validate final config)" do
    expect(subject.load(fixture("dsl/load.eye"))).to be_ok
    expect(subject.load(fixture("dsl/load2.eye"))).to be_ok
    res = subject.load(fixture("dsl/load2_*.eye"))
    expect(res.size).to be > 1
    expect(res).to have_error_count 1

    expect(res.keys.grep(/load2_dup_pid\.eye/).values).to eq([
      hash_including(:error => true, :message=>"duplicate pid_files: {\"/tmp/app3-e1.pid\"=>2}"),
    ])
  end

  it "dups of pid_files, but they different with expand" do
    expect(subject.load(fixture("dsl/load2_dup2.eye"))).to be_ok
  end

  it "dups of names but in different scopes" do
    expect(subject.load(fixture("dsl/load_dup_ex_names.eye"))).to be_ok
  end

  it "processes with same names in different scopes should not create new processes on just update" do
    expect(subject.load(fixture("dsl/load_dup_ex_names.eye"))).to be_ok
    p1 = subject.process_by_full_name('app1:p1:server')
    p2 = subject.process_by_full_name('app1:p2:server')

    expect(subject.load(fixture("dsl/load_dup_ex_names2.eye"))).to be_ok

    t = subject.short_tree
    expect(t['app1']['p1']['server']).to match('server1.pid')
    expect(t['app1']['p2']['server']).to match('server2.pid')

    p12 = subject.process_by_full_name('app1:p1:server')
    p22 = subject.process_by_full_name('app1:p2:server')

    expect(p12.object_id).to eq p1.object_id
    expect(p22.object_id).to eq p2.object_id
  end

  it "same processes crossed in apps duplicate pids" do
    expect(subject.load(fixture("dsl/load_dup_ex_names3.eye"))).to have_error_count 1
  end

  it "same processes crossed in apps" do
    expect(subject.load(fixture("dsl/load_dup_ex_names4.eye"))).to be_ok
    p1 = subject.process_by_full_name('app1:gr:server')
    p2 = subject.process_by_full_name('app2:gr:server')
    expect(p1.object_id).not_to eq p2.object_id

    expect(subject.load(fixture("dsl/load_dup_ex_names4.eye"))).to be_ok
    p12 = subject.process_by_full_name('app1:gr:server')
    p22 = subject.process_by_full_name('app2:gr:server')

    expect(p12.object_id).to eq p1.object_id
    expect(p22.object_id).to eq p2.object_id
  end

  it "order of applications and groups" do
    subject.load_content(<<-F)
      Eye.app(:app2) { }
      Eye.app(:app1) {
        process("p"){ pid_file "1" }
        group(:gr3){}
        group(:gr2){}
        group(:gr1){}
      }
    F

    expect(subject.applications.map(&:name)).to eq %w{app1 app2}
    app = subject.applications[0]
    expect(app.groups.map(&:name)).to eq %w{gr1 gr2 gr3 __default__}
  end

  describe "configs" do
    after(:each){ set_glogger }

    it "load logger" do
      expect(subject.load(fixture("dsl/load_logger.eye"))).to be_ok
      expect(Eye::Logger.dev).to eq "/tmp/1.loG"
    end

    it "set logger when load multiple configs" do
      expect(subject.load(fixture("dsl/load_logger{,2}.eye"))).to be_ok(2)
      expect(Eye::Logger.dev).to eq "/tmp/1.loG"
    end

    it "load logger with rotation" do
      subject.load_content(<<-S)
        Eye.config { logger "/tmp/1.log", 7, 10000 }
      S
      expect(Eye::Logger.dev).to eq "/tmp/1.log"
    end

    it "not set bad logger" do
      expect(subject.load(fixture("dsl/load_logger.eye"))).to be_ok
      expect(Eye::Logger.dev).to eq "/tmp/1.loG"

      res = subject.load_content(<<-S)
        Eye.config { logger "/tmp/asdfasdf/sd/f/sdf/sd/f/sdf/s" }
      S

      expect(Eye::Logger.dev).to eq "/tmp/1.loG"
      expect(subject.current_config.settings).to eq({:logger=>["/tmp/1.loG"], :logger_level => 0})
    end

    it "not set bad logger" do
      subject.load_content(" Eye.config { logger 1 } ")
      expect(Eye::Logger.dev).to be
    end

    it "set custom logger" do
      subject.load_content(" Eye.config { logger Logger.new('/tmp/eye_temp.log') } ")
      expect(Eye::Logger.dev.instance_variable_get(:@logdev).filename).to eq '/tmp/eye_temp.log'
    end

    it "set syslog" do
      subject.load_content(" Eye.config { logger syslog } ")
      if RUBY_VERSION <= '1.9.3'
        expect(Eye::Logger.dev).to be_a(String)
      else
        expect(Eye::Logger.dev).to be_a(Syslog::Logger)
      end
    end

    it "should corrent load config section" do
      expect(subject.load(fixture("dsl/configs/{1,2}.eye"))).to be_ok(2)
      expect(Eye::Logger.dev).to eq "/tmp/a.log"
      expect(subject.current_config.settings).to eq({:logger=>["/tmp/a.log"], :http=>{:enable=>true}})

      expect(subject.load(fixture("dsl/configs/3.eye"))).to be_ok
      expect(Eye::Logger.dev).to eq "/tmp/a.log"
      expect(subject.current_config.settings).to eq({:logger=>["/tmp/a.log"], :http=>{:enable=>false}})

      expect(subject.load(fixture("dsl/configs/4.eye"))).to be_ok
      expect(Eye::Logger.dev).to eq nil
      expect(subject.current_config.settings).to eq({:logger=>[nil], :http=>{:enable=>false}})

      expect(subject.load(fixture("dsl/configs/2.eye"))).to be_ok
      expect(Eye::Logger.dev).to eq nil
      expect(subject.current_config.settings).to eq({:logger=>[nil], :http=>{:enable=>true}})
    end

    it "should load not settled config option" do
      expect(subject.load(fixture("dsl/configs/5.eye"))).to be_ok
    end
  end


  it "load folder" do
    expect(subject.load(fixture("dsl/load_folder/"))).to be_ok(2)
    expect(subject.short_tree).to eq({
      "app3" => {"wow"=>{"e1"=>"/tmp/app3-e1.pid"}},
      "app4" => {"__default__"=>{"e2"=>"/tmp/app4-e2.pid"}}
    })
  end

  it "load folder with error" do
    expect(subject.load(fixture("dsl/load_error_folder/"))).to have_error_count 1
  end

  it "load files by mask" do
    expect(subject.load(fixture("dsl/load_folder/*.eye"))).to be_ok(2)
    expect(subject.short_tree).to eq({
      "app3" => {"wow"=>{"e1"=>"/tmp/app3-e1.pid"}},
      "app4" => {"__default__"=>{"e2"=>"/tmp/app4-e2.pid"}}
    })
  end

  it "load files by mask with error" do
    expect(subject.load(fixture("dsl/load_error_folder/*.eye"))).to have_error_count 1
  end

  it "load not files with mask" do
    expect(subject.load(fixture("dsl/load_folder/*.bla"))).to have_error_count 1
  end

  it "bad mask" do
    s = " asdf asdf afd d"
    res = subject.load(s)
    expect(res[s][:error]).to eq true
    expect(res[s][:message]).to include(s)
  end

  it "group update it settings" do
    expect(subject.load(fixture("dsl/load.eye"))).to be_ok
    app = subject.application_by_name('app1')
    gr = subject.group_by_name('gr2')
    expect(gr.config[:chain]).to eq({:restart => {:grace=>0.5, :action=>:restart}, :start => {:grace=>0.5, :action=>:start}})

    expect(subject.load(fixture("dsl/load6.eye"))).to be_ok
    sleep 1

    expect(gr.config[:chain]).to eq({:restart => {:grace=>1.0, :action=>:restart}, :start => {:grace=>1.0, :action=>:start}})
  end

  it "load multiple apps with cross constants" do
    expect(subject.load(fixture('dsl/subfolder{2,3}.eye'))).to be_ok(2)
    expect(subject.process_by_name('e1')[:working_dir]).to eq '/tmp'
    expect(subject.process_by_name('e2')[:working_dir]).to eq '/var'

    expect(subject.process_by_name('e3')[:working_dir]).to eq '/tmp'
    expect(subject.process_by_name('e4')[:working_dir]).to eq '/'
  end

  it "raised load" do
    res = subject.load(fixture("dsl/load_error.eye"))
    expect(res.size).to eq(1)
    expect(res.values[0][:error]).to eq true
    expect(res.values[0][:message]).to include("/asd/fasd/fas/df/asd/fas/df/d")
    set_glogger
  end

  describe "synchronize groups" do
    it "correctly schedule monitor for groups and processes" do
      expect(subject.load(fixture("dsl/load_int.eye"))).to be_ok
      sleep 0.5

      p0 = subject.process_by_name 'p0'
      p1 = subject.process_by_name 'p1'
      p2 = subject.process_by_name 'p2'
      gr1 = subject.group_by_name 'gr1'
      gr_ = subject.group_by_name '__default__'

      expect(p0.scheduler_history.states).to eq [:monitor]
      expect(p1.scheduler_history.states).to eq [:monitor]
      expect(p2.scheduler_history.states).to eq [:monitor]
      expect(gr1.scheduler_history.states).to eq [:monitor]
      expect(gr_.scheduler_history.states).to eq [:monitor]

      expect(subject.load(fixture("dsl/load_int2.eye"))).to be_ok
      sleep 0.5

      expect(p1.alive?).to eq false
      expect(p0.alive?).to eq false

      p01 = subject.process_by_name 'p0-1'
      p4 = subject.process_by_name 'p4'
      p5 = subject.process_by_name 'p5'
      gr2 = subject.group_by_name 'gr2'

      expect(p2.scheduler_history.states).to eq [:monitor, :update_config]
      expect(gr1.scheduler_history.states).to eq [:monitor, :update_config]
      expect(gr_.scheduler_history.states).to eq [:monitor, :update_config]

      expect(p01.scheduler_history.states).to eq [:monitor]
      expect(p4.scheduler_history.states).to eq [:monitor]
      expect(p5.scheduler_history.states).to eq [:monitor]
      expect(gr2.scheduler_history.states).to eq [:monitor]
    end
  end

  describe "load is exclusive" do
    it "run double in time" do
      subject.async.command(:load, fixture("dsl/long_load.eye"))
      subject.async.command(:load, fixture("dsl/long_load.eye"))
      sleep 2.5
      should_spend(0, 0.6) do
        expect(subject.command(:info_data)).to be_a(Hash)
      end
    end

    it "load with subloads" do
      silence_warnings{
        subject.command(:load, fixture("dsl/subfolder2.eye"))
      }
      sleep 0.5
      should_spend(0, 0.2) do
        expect(subject.command(:info_data)).to be_a(Hash)
      end
    end
  end

  describe "cleanup configs on delete" do
    it "load config, delete 1 process, load another config" do
      subject.load(fixture('dsl/load.eye'))
      expect(subject.process_by_name('p1')).to be

      subject.command(:delete, "p1"); sleep 0.1
      expect(subject.process_by_name('p1')).to be_nil

      subject.load(fixture('dsl/load2.eye'))
      expect(subject.process_by_name('p1')).to be_nil
    end

    it "load config, delete 1 group, load another config" do
      subject.load(fixture('dsl/load.eye'))
      expect(subject.group_by_name('gr1')).to be

      subject.command(:delete, "gr1"); sleep 0.1
      expect(subject.group_by_name('p1')).to be_nil

      subject.load(fixture('dsl/load2.eye'))
      expect(subject.group_by_name('gr1')).to be_nil
    end

    it "load config, then delete app, and load it with changed app-name" do
      subject.load(fixture('dsl/load3.eye'))
      subject.command(:delete, "app3"); sleep 0.1
      expect(subject.load(fixture('dsl/load4.eye'))).to be_ok
    end

    it "delete from empty app (was an exception)" do
      subject.load_content(<<-F)
        Eye.app(:bla) { }
        Eye.app(:good) { group(:gr){}; process(:pr){ pid_file '1'} }
      F
      subject.command(:delete, "pr")
      subject.command(:delete, "gr")
      subject.command(:delete, "good")
      subject.command(:delete, "bla")
    end
  end

  it "should update only changed apps" do
    expect(subject).to receive(:update_or_create_application).with('app1', kind_of(Hash))
    expect(subject).to receive(:update_or_create_application).with('app2', kind_of(Hash))
    subject.load(fixture('dsl/load.eye'))

    expect(subject).to receive(:update_or_create_application).with('app3', kind_of(Hash))
    subject.load(fixture('dsl/load2.eye'))

    expect(subject).to receive(:update_or_create_application).with('app3', kind_of(Hash))
    subject.load(fixture('dsl/load3.eye'))
  end

  describe "load multiple" do
    after(:each){ set_glogger }

    it "ok load 2 configs" do
      expect(subject.load(fixture("dsl/configs/1.eye"), fixture("dsl/configs/2.eye"))).to be_ok(2)
    end

    it "load 2 configs, 1 not exists" do
      res = subject.load(fixture("dsl/configs/1.eye"), fixture("dsl/configs/dddddd.eye"))
      expect(res.size).to be > 1
      expect(res).to have_error_count 1
    end

    it "multiple + folder" do
      res = subject.load(fixture("dsl/load.eye"), fixture("dsl/load_folder/"))
      expect(res.size).to eq 3
      expect(res.values.count{ |res| res[:error] }).to eq 0
    end
  end

  describe "Load double processes with same names (was a bug)" do

    it "2 apps with procecesses with the same name" do
      cfg = <<-S
        Eye.app(:app) do
          group(:gr1) { process(:p) { pid_file "1.pid" } }
          group(:gr2) { process(:p) { pid_file "2.pid" } }
        end
      S

      subject.load_content(cfg)
      subject.load_content(cfg)

      expect(Celluloid::Actor.all.select { |c| c.class == Eye::Process }.size).to eq 2
    end

    it "2 process in different apps in __default__" do
      cfg = <<-S
        Eye.app(:app1) { process(:p) { pid_file "1.pid" } }
        Eye.app(:app2) { process(:p) { pid_file "2.pid" } }
      S

      subject.load_content(cfg)
      subject.load_content(cfg)

      expect(Celluloid::Actor.all.select { |c| c.class == Eye::Process }.size).to eq 2
    end

    it "2 process in different apps" do
      cfg = <<-S
        Eye.app(:app1) { group(:gr1) { process(:p) { pid_file "1.pid" } } }
        Eye.app(:app2) { group(:gr2) { process(:p) { pid_file "2.pid" } } }
      S

      subject.load_content(cfg)
      subject.load_content(cfg)

      expect(Celluloid::Actor.all.select { |c| c.class == Eye::Process }.size).to eq 2
      expect(Celluloid::Actor.all.select { |c| c.class == Eye::Group }.size).to eq 2
    end

    it "2 groups" do
      cfg = <<-S
        Eye.app(:app1) { group(:gr){} }
        Eye.app(:app2) { group(:gr){} }
      S

      subject.load_content(cfg)
      subject.load_content(cfg)

      expect(Celluloid::Actor.all.select { |c| c.class == Eye::Group }.size).to eq 2
    end
  end

  it "contacts bug #118" do
    subject.load(fixture("dsl/contact1.eye"), fixture("dsl/contact2.eye"))
    expect(subject.settings[:contacts].keys.sort).to eq %w{contact1 contact2}
  end

  it "using shared object" do
    cfg1 = <<-S
      Eye.shared.bla = {"1" => "2"}
    S

    cfg2 = <<-S2
      Eye.app(:app2) { process(:p) { pid_file "2.pid"; env Eye.shared.bla; env "3" => "4" } }
    S2

    subject.load_content(cfg1)
    subject.load_content(cfg2)
    expect(subject.process_by_name('p').config[:environment]).to eq({"1" => "2", "3" => "4"})
  end

  describe "default app" do
    it "load in one config" do
      cfg1 = <<-S
        Eye.app :__default__ do
          env "A" => "B"
        end
        Eye.app :some do
        end
      S
      subject.load_content(cfg1)
      expect(subject.application_by_name('some').config[:environment]).to eq({"A" => "B"})
      expect(subject.application_by_name('__default__')).to eq nil
      expect(subject.application_by_name('some').config[:application]).to be_nil
    end

    it "should merge defaults in one config" do
      cfg1 = <<-S
        Eye.app :__default__ do
          env "A" => "B"
        end
        Eye.app :__default__ do
          env "C" => "D"
        end
        Eye.app :some do
        end
      S
      subject.load_content(cfg1)
      expect(subject.application_by_name('some').config[:environment]).to eq({"A" => "B", "C" => "D"})
      expect(subject.application_by_name('__default__')).to eq nil
    end

    it "should rewrite defaults in one config" do
      cfg1 = <<-S
        Eye.app :__default__ do
          stop_signals :term, 10
        end
        Eye.app :__default__ do
          stop_signals :term, 11
        end
        Eye.app :some do
        end
      S
      subject.load_content(cfg1)
      expect(subject.application_by_name('some').config[:stop_signals]).to eq [:term, 11]
    end

    it "should rewrite defaults check in one config" do
      cfg1 = <<-S
        Eye.app :__default__ do
          check :memory, :below => 10
        end
        Eye.app :__default__ do
          check :memory, :below => 11
        end
        Eye.app :some do
        end
      S
      subject.load_content(cfg1)
      expect(subject.application_by_name('some').config[:checks]).to eq({:memory=>{:below=>11, :type=>:memory}})
    end

    it "should not accept group and process inside __default__ app" do
      cfg1 = <<-S
        Eye.app :__default__ do
          stdall "/tmp/2"
          group :bla do
            process(:a) { pid_file '/tmp/1' }
          end
        end
        Eye.app :some do
        end
      S
      subject.load_content(cfg1)
      expect(subject.application_by_name('some').config[:groups]).to eq nil
      expect(subject.application_by_name('some').config[:stdall]).to eq '/tmp/2'
    end

    it "load two configs per one load" do
      subject.load(fixture('dsl/default1.eye'), fixture('dsl/default2.eye'))
      expect(subject.application_by_name('some').config[:environment]).to eq({"A" => "B"})
      expect(subject.application_by_name('__default__')).to eq nil
    end

    it "load in two configs" do
      subject.load(fixture('dsl/default1.eye'))
      subject.load(fixture('dsl/default2.eye'))
      expect(subject.application_by_name('some').config[:environment]).to eq({"A" => "B"})
      expect(subject.application_by_name('__default__')).to eq nil
    end

    it "load in two configs, with merge default" do
      subject.load(fixture('dsl/default1.eye'))
      subject.load(fixture('dsl/default3.eye'))
      expect(subject.application_by_name('some').config[:environment]).to eq({"A" => "B", "C" => "D"})
      expect(subject.application_by_name('__default__')).to eq nil
    end

    it "load in two configs, with merge default" do
      subject.load(fixture('dsl/default4.eye'))
      subject.load(fixture('dsl/default2.eye'))
      appcfg = subject.application_by_name('some').config
      expect(subject.application_by_name('__default__')).to eq nil
      expect(appcfg[:checks].keys).to eq [:memory]
      expect(appcfg[:triggers].keys).to eq [:stop_children]
    end
  end

  describe "valiadate localize params" do
    it "validate correct working_dir" do
      conf = <<-E
        Eye.application("bla") do
          process("1") do
            pid_file "1.pid"
            working_dir "/tmp"
          end
        end
      E
      expect(subject.load_content(conf)).to be_ok

      conf = <<-E
        Eye.application("bla") do
          process("1") do
            pid_file "1.pid"
            working_dir "/tmp/asdfsdf//sdf/asdf/asd/f/asdf"
          end
        end
      E
      expect(subject.load_content(conf)).to have_error_count 1
      expect{ Eye::Dsl.parse_apps(conf) }.not_to raise_error
    end

    it "when load new project, and old working_dir for another project is invalid" do
      conf = <<-E
        Eye.application("bla") do
          process("1") do
            pid_file "1.pid"
            working_dir "/tmp"
          end
        end
      E
      expect(subject.load_content(conf)).to be_ok

      # patch here controller config, to emulate spec
      subject.current_config.applications['bla'][:groups]['__default__'][:processes]['1'][:working_dir] = '/tmp2'

      conf = <<-E
        Eye.application("bla2") do
          process("2") do
            pid_file "2.pid"
            working_dir "/tmp"
          end
        end
      E
      expect(subject.load_content(conf)).to be_ok
    end

    [:uid, :gid].each do |s|
      it "validate user #{s}" do
        conf = <<-E
          Eye.application("bla") do
            process("1") do
              pid_file "1.pid"
              #{s} "root"
            end
          end
        E
        if RUBY_VERSION < '2.0' || (s == :gid && RUBY_PLATFORM.include?('darwin'))
          expect(subject.load_content(conf)).to have_error_count 1
        else
          expect(subject.load_content(conf)).to be_ok
        end

        conf = <<-E
          Eye.application("bla") do
            process("1") do
              pid_file "1.pid"
              #{s} "asdfasdff23rf234f323f"
            end
          end
        E
        expect(subject.load_content(conf)).to have_error_count 1
      end
    end

  end
end
