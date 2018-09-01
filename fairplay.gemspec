Gem::Specification.new do |s|
  s.name          = "fairplay"
  s.summary       = "A rate limited enqueuer for Sidekiq "
  s.version       = `cat VERSION`
  s.date          = "2018-09-01"
  s.authors       = ["Nisanth Chunduru"]
  s.email         = ["nisanth074@gmail.com"]
  s.files         = Dir["{lib}/**/*"] + ["README.md"]

  s.add_dependency("sidekiq")
  s.add_dependency("ratelimit")
  s.add_dependency("activesupport")

  s.add_development_dependency("rspec", "~> 3.0")
  s.add_development_dependency("flexmock")
  s.add_development_dependency("timecop")
  s.add_development_dependency("pry")
end
